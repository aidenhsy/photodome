import type { INestApplication } from '@nestjs/common';
import { getQueueToken } from '@nestjs/bullmq';
import { Test } from '@nestjs/testing';
import { Storage } from '@google-cloud/storage';
import type { Queue } from 'bullmq';
import { createHash } from 'node:crypto';
import type { AddressInfo } from 'node:net';
import type { Server } from 'node:http';
import request from 'supertest';
import sharp from 'sharp';
import { io, type Socket } from 'socket.io-client';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/common/bootstrap/configure-app';
import { PrismaService } from '../src/common/prisma/prisma.service';
import { EVENT_EXPIRY_QUEUE } from '../src/modules/expiry/application/expiry.constants';

jest.setTimeout(40_000);

interface HostAccess {
  event: { id: string };
  capability: string;
  joinCode: string;
}

interface GuestAccess {
  event: { id: string };
  capability: string;
}

interface UploadGrant {
  photoId: string;
  uploadUrl: string;
}

describe('Event expiry and permanent cleanup (e2e)', () => {
  let app: INestApplication;
  let server: Server;
  let prisma: PrismaService;
  let queue: Queue;
  let baseUrl: string;
  let socket: Socket | undefined;
  const bucket = new Storage({
    projectId: 'photodome-test',
    apiEndpoint: 'http://127.0.0.1:4443',
    useAuthWithCustomEndpoint: false,
  }).bucket('photodome-media-dev');

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = module.createNestApplication();
    configureApp(app);
    await app.listen(0, '127.0.0.1');
    server = app.getHttpServer() as Server;
    const address = server.address() as AddressInfo;
    baseUrl = `http://127.0.0.1:${address.port}`;
    prisma = app.get(PrismaService);
    queue = app.get<Queue>(getQueueToken(EVENT_EXPIRY_QUEUE));
  });

  beforeEach(async () => {
    await queue.drain(true);
    await prisma.eventCleanupTombstone.deleteMany();
    await prisma.event.deleteMany();
    await bucket.deleteFiles({ prefix: 'events/', force: true });
  });

  afterAll(async () => {
    await app.close();
  });

  afterEach(() => {
    socket?.disconnect();
    socket = undefined;
  });

  it('revokes access, deletes every object generation, and purges all metadata', async () => {
    const host = (
      await request(server)
        .post('/v1/events')
        .send({ name: 'Short TTL cleanup', displayName: 'Expiry Host' })
        .expect(201)
    ).body as HostAccess;
    const guest = (
      await request(server)
        .post('/v1/events/join')
        .send({ joinCode: host.joinCode, displayName: 'Expiry Guest' })
        .expect(200)
    ).body as GuestAccess;
    const eventId = host.event.id;
    socket = io(baseUrl, {
      transports: ['websocket'],
      auth: { eventId, capability: guest.capability },
    });
    await waitForSocket(socket, 'connect');

    const jpeg = await sharp({
      create: {
        width: 320,
        height: 240,
        channels: 3,
        background: { r: 12, g: 12, b: 12 },
      },
    })
      .jpeg({ quality: 90 })
      .toBuffer();
    const reservation = (
      await request(server)
        .post(`/v1/events/${eventId}/photos/reservations`)
        .set('Authorization', `Bearer ${guest.capability}`)
        .send({
          contentType: 'image/jpeg',
          byteSize: jpeg.byteLength,
          sha256: createHash('sha256').update(jpeg).digest('hex'),
          width: 320,
          height: 240,
          capturedAt: '2026-07-25T00:00:00.000Z',
          orientation: 1,
        })
        .expect(201)
    ).body as UploadGrant;
    const uploaded = await fetch(reservation.uploadUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': 'image/jpeg',
        'Content-Length': String(jpeg.byteLength),
        'Content-Range': `bytes 0-${jpeg.byteLength - 1}/${jpeg.byteLength}`,
      },
      body: jpeg,
    });
    expect(uploaded.ok).toBe(true);
    await request(server)
      .post(`/v1/events/${eventId}/photos/${reservation.photoId}/complete`)
      .set('Authorization', `Bearer ${guest.capability}`)
      .expect(200);
    await waitUntil(async () => {
      const photo = await prisma.photo.findUnique({
        where: { id: reservation.photoId },
      });
      return photo?.state === 'READY';
    });

    await request(server)
      .post(`/v1/events/${eventId}/end`)
      .set('Authorization', `Bearer ${host.capability}`)
      .expect(200);
    await request(server)
      .put(`/v1/events/${eventId}/selections/${reservation.photoId}`)
      .set('Authorization', `Bearer ${host.capability}`)
      .send({ decision: 'KEEP' })
      .expect(200);
    await request(server)
      .post(`/v1/events/${eventId}/host-transfer`)
      .set('Authorization', `Bearer ${host.capability}`)
      .send({ joinCode: host.joinCode })
      .expect(200);
    await bucket
      .file(`events/${eventId}/abandoned/upload.tmp`)
      .save(Buffer.from('late orphan'), { resumable: false });

    await prisma.event.update({
      where: { id: eventId },
      data: { expiresAt: new Date(Date.now() - 1_000) },
    });
    await request(server)
      .get(`/v1/events/${eventId}`)
      .set('Authorization', `Bearer ${guest.capability}`)
      .expect(401);

    const expiredSignal = waitForSocket(socket, 'event.expired');
    await queue.add(
      'cleanup-event',
      { eventId },
      {
        jobId: `short-ttl-${eventId}`,
        delay: 50,
        attempts: 3,
        removeOnComplete: true,
      },
    );
    expect(await expiredSignal).toEqual({ eventId });

    await waitUntil(async () => {
      const [event, tombstone, files] = await Promise.all([
        prisma.event.findUnique({ where: { id: eventId } }),
        prisma.eventCleanupTombstone.findUnique({ where: { eventId } }),
        bucket.getFiles({
          prefix: `events/${eventId}/`,
          versions: true,
        }),
      ]);
      return event === null && tombstone === null && files[0].length === 0;
    });

    const [members, photos, selections, transfers] = await Promise.all([
      prisma.eventMember.count({ where: { eventId } }),
      prisma.photo.count({ where: { eventId } }),
      prisma.photoSelection.count({ where: { eventId } }),
      prisma.hostTransferToken.count({ where: { eventId } }),
    ]);
    expect({ members, photos, selections, transfers }).toEqual({
      members: 0,
      photos: 0,
      selections: 0,
      transfers: 0,
    });

    await request(server).get('/v1/internal/metrics').expect(401);
    const metrics = await request(server)
      .get('/v1/internal/metrics')
      .set(
        'Authorization',
        'Bearer test-only-metrics-token-at-least-32-characters',
      )
      .expect(200);
    expect(metrics.text).toContain('photodome_cleanup_attempts_total');
    expect(metrics.text).toContain('photodome_cleanup_objects_deleted_total');
  });
});

function waitForSocket(socket: Socket, event: string): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error(`Timed out waiting for socket event ${event}`));
    }, 10_000);
    socket.once(event, (payload: unknown) => {
      clearTimeout(timeout);
      resolve(payload);
    });
  });
}

async function waitUntil(
  condition: () => Promise<boolean>,
  timeoutMs = 15_000,
): Promise<void> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (await condition()) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error('Timed out waiting for verified event cleanup');
}

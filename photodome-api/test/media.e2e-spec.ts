import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Storage } from '@google-cloud/storage';
import type { AddressInfo } from 'node:net';
import { createHash } from 'node:crypto';
import type { Server } from 'node:http';
import request from 'supertest';
import sharp from 'sharp';
import { io, type Socket } from 'socket.io-client';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/common/bootstrap/configure-app';
import { PrismaService } from '../src/common/prisma/prisma.service';

jest.setTimeout(30_000);

interface HostEventAccessBody {
  event: { id: string };
  capability: string;
  joinCode: string;
}

interface EventAccessBody {
  event: { id: string };
  capability: string;
}

interface UploadGrantBody {
  photoId: string;
  uploadUrl: string;
  contentType: string;
  byteSize: number;
  state: string;
}

interface PhotoPageBody {
  photos: Array<{
    id: string;
    displayUrl: string;
    thumbnailUrl: string;
  }>;
  nextCursor: string | null;
  readyPhotoCount: number;
}

describe('Direct media upload and live album (e2e)', () => {
  let app: INestApplication;
  let server: Server;
  let prisma: PrismaService;
  let baseUrl: string;
  const storage = new Storage({
    projectId: 'photodome-test',
    apiEndpoint: 'http://127.0.0.1:4443',
    useAuthWithCustomEndpoint: false,
    retryOptions: {
      autoRetry: false,
      maxRetries: 0,
      totalTimeout: 5_000,
    },
  });

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
  });

  beforeEach(async () => {
    await prisma.eventCleanupTombstone.deleteMany();
    await prisma.photo.deleteMany();
    await prisma.hostTransferToken.deleteMany();
    await prisma.eventMember.deleteMany();
    await prisma.event.deleteMany();
    await storage
      .bucket('photodome-media-dev')
      .deleteFiles({ prefix: 'events/' });
  });

  afterAll(async () => {
    await app.close();
  });

  it('uploads directly, verifies/processes, and announces READY', async () => {
    const host = (
      await request(server)
        .post('/v1/events')
        .send({
          name: 'Live album integration',
          displayName: 'Album Host',
        })
        .expect(201)
    ).body as HostEventAccessBody;
    const guest = (
      await request(server)
        .post('/v1/events/join')
        .set('X-PhotoDome-Installation-ID', 'media-guest-installation')
        .send({ joinCode: host.joinCode, displayName: 'Album Guest' })
        .expect(200)
    ).body as EventAccessBody;

    const socket = io(baseUrl, {
      transports: ['websocket'],
      auth: {
        eventId: host.event.id,
        capability: host.capability,
      },
    });
    await waitForSocket(socket, 'connect');

    const jpeg = await sharp({
      create: {
        width: 1_200,
        height: 800,
        channels: 3,
        background: { r: 18, g: 18, b: 18 },
      },
    })
      .jpeg({ quality: 92 })
      .toBuffer();
    const sha256 = createHash('sha256').update(jpeg).digest('hex');

    const reservation = (
      await request(server)
        .post(`/v1/events/${host.event.id}/photos/reservations`)
        .set('Authorization', `Bearer ${guest.capability}`)
        .send({
          contentType: 'image/jpeg',
          byteSize: jpeg.byteLength,
          sha256,
          width: 1_200,
          height: 800,
          capturedAt: '2026-07-25T00:00:00.000Z',
          orientation: 1,
        })
        .expect(201)
    ).body as UploadGrantBody;

    expect(reservation.state).toBe('RESERVED');
    expect(reservation.uploadUrl).toContain('127.0.0.1:4443');

    const uploadResponse = await fetch(reservation.uploadUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': 'image/jpeg',
        'Content-Length': String(jpeg.byteLength),
        'Content-Range': `bytes 0-${jpeg.byteLength - 1}/${jpeg.byteLength}`,
      },
      body: jpeg,
    });
    expect(uploadResponse.ok).toBe(true);

    const readyEvent = waitForSocket(socket, 'event.photo_ready');
    const completion = await request(server)
      .post(
        `/v1/events/${host.event.id}/photos/${reservation.photoId}/complete`,
      )
      .set('Authorization', `Bearer ${guest.capability}`)
      .expect(200);
    expect((completion.body as { state: string }).state).toBe('PROCESSING');

    const eventPayload = (await readyEvent) as {
      eventId: string;
      photoId: string;
    };
    expect(eventPayload).toEqual({
      eventId: host.event.id,
      photoId: reservation.photoId,
    });

    const album = (
      await request(server)
        .get(`/v1/events/${host.event.id}/photos`)
        .set('Authorization', `Bearer ${host.capability}`)
        .expect(200)
    ).body as PhotoPageBody;
    expect(album.photos).toHaveLength(1);
    expect(album.readyPhotoCount).toBe(1);
    expect(album.photos[0]?.id).toBe(reservation.photoId);
    expect(album.nextCursor).toBeNull();

    const storedPhoto = await prisma.photo.findUniqueOrThrow({
      where: { id: reservation.photoId },
    });
    const [storedMaster] = await storage
      .bucket('photodome-media-dev')
      .file(storedPhoto.originalKey)
      .download();
    expect(storedMaster.equals(jpeg)).toBe(true);

    const thumbnail = await fetch(album.photos[0]!.thumbnailUrl);
    expect(thumbnail.ok).toBe(true);
    expect(thumbnail.headers.get('content-type')).toBe('image/jpeg');
    const thumbnailMetadata = await sharp(
      Buffer.from(await thumbnail.arrayBuffer()),
    ).metadata();
    expect(thumbnailMetadata.width).toBeLessThanOrEqual(512);
    expect(thumbnailMetadata.height).toBeLessThanOrEqual(512);
    expect(thumbnailMetadata.exif).toBeUndefined();

    await request(server)
      .delete(`/v1/events/${host.event.id}/photos/${reservation.photoId}`)
      .set('Authorization', `Bearer ${host.capability}`)
      .expect(404);

    const removedEvent = waitForSocket(socket, 'event.photo_removed');
    await request(server)
      .delete(`/v1/events/${host.event.id}/photos/${reservation.photoId}`)
      .set('Authorization', `Bearer ${guest.capability}`)
      .expect(204);
    expect(await removedEvent).toEqual({
      eventId: host.event.id,
      photoId: reservation.photoId,
    });

    const moderatedAlbum = (
      await request(server)
        .get(`/v1/events/${host.event.id}/photos`)
        .set('Authorization', `Bearer ${host.capability}`)
        .expect(200)
    ).body as PhotoPageBody;
    expect(moderatedAlbum.photos).toHaveLength(0);
    expect(moderatedAlbum.readyPhotoCount).toBe(0);

    await waitUntil(async () => {
      const [photo, files] = await Promise.all([
        prisma.photo.findUnique({ where: { id: reservation.photoId } }),
        storage.bucket('photodome-media-dev').getFiles({
          prefix: `events/${host.event.id}/photos/${reservation.photoId}/`,
        }),
      ]);
      return photo === null && files[0].length === 0;
    });

    socket.disconnect();
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
  timeoutMs = 10_000,
): Promise<void> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (await condition()) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error('Timed out waiting for asynchronous cleanup');
}

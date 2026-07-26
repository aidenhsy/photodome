import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/common/bootstrap/configure-app';
import { PrismaService } from '../src/common/prisma/prisma.service';

interface EventSnapshotBody {
  id: string;
  name: string;
  hostDisplayName: string;
  locationLabel: string | null;
  state: 'LIVE' | 'ENDED' | 'EXPIRING';
  memberCount: number;
  readyPhotoCount: number;
  endedAt: string | null;
  expiresAt: string | null;
  uploadsRestrictedAt: string | null;
  viewer: {
    memberId: string;
    role: 'HOST' | 'GUEST';
  };
}

interface EventAccessBody {
  event: EventSnapshotBody;
  capability: string;
}

interface HostEventAccessBody extends EventAccessBody {
  joinCode: string;
}

describe('Accountless event spine (e2e)', () => {
  let app: INestApplication;
  let server: Server;
  let prisma: PrismaService;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = module.createNestApplication();
    configureApp(app);
    await app.init();
    server = app.getHttpServer() as Server;
    prisma = app.get(PrismaService);
  });

  beforeEach(async () => {
    await prisma.eventCleanupTombstone.deleteMany();
    await prisma.hostTransferToken.deleteMany();
    await prisma.eventMember.deleteMany();
    await prisma.event.deleteMany();
  });

  afterAll(async () => {
    await app.close();
  });

  it('lets two accountless devices create, join, and read privately', async () => {
    const createdResponse = await request(server)
      .post('/v1/events')
      .send({
        name: "James's birthday",
        displayName: 'James',
        locationLabel: 'Tokyo',
      })
      .expect(201);
    const created = createdResponse.body as HostEventAccessBody;

    expect(created.capability).toMatch(/^pdc_/);
    expect(created.joinCode).toMatch(/^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{8}$/);
    expect(created.event).toMatchObject({
      name: "James's birthday",
      hostDisplayName: 'James',
      locationLabel: 'Tokyo',
      state: 'LIVE',
      memberCount: 1,
      readyPhotoCount: 0,
      viewer: { role: 'HOST' },
    });

    await request(server).get(`/v1/events/${created.event.id}`).expect(401);

    const formattedCode = `${created.joinCode.slice(
      0,
      4,
    )}-${created.joinCode.slice(4)}`;
    const joinedResponse = await request(server)
      .post('/v1/events/join')
      .send({ joinCode: formattedCode, displayName: 'Taylor' })
      .expect(200);
    const joined = joinedResponse.body as EventAccessBody;

    expect(joined.capability).toMatch(/^pdc_/);
    expect(joined.capability).not.toBe(created.capability);
    expect(joined.event).toMatchObject({
      id: created.event.id,
      memberCount: 2,
      viewer: { role: 'GUEST' },
    });

    const hostSnapshotResponse = await request(server)
      .get(`/v1/events/${created.event.id}`)
      .set('Authorization', `Bearer ${created.capability}`)
      .expect(200);
    const hostSnapshot = hostSnapshotResponse.body as EventSnapshotBody;
    expect(hostSnapshot.memberCount).toBe(2);

    const guestSnapshotResponse = await request(server)
      .get(`/v1/events/${created.event.id}`)
      .set('Authorization', `Bearer ${joined.capability}`)
      .expect(200);
    const guestSnapshot = guestSnapshotResponse.body as EventSnapshotBody;
    expect(guestSnapshot.viewer.role).toBe('GUEST');
  });

  it('rotates public invites without revoking existing members', async () => {
    const created = (
      await request(server)
        .post('/v1/events')
        .send({ name: 'Private party', displayName: 'Alex' })
        .expect(201)
    ).body as HostEventAccessBody;
    const guest = (
      await request(server)
        .post('/v1/events/join')
        .send({ joinCode: created.joinCode, displayName: 'Sam' })
        .expect(200)
    ).body as EventAccessBody;

    await request(server)
      .post(`/v1/events/${created.event.id}/rotate-code`)
      .set('Authorization', `Bearer ${guest.capability}`)
      .expect(403);

    const rotatedResponse = await request(server)
      .post(`/v1/events/${created.event.id}/rotate-code`)
      .set('Authorization', `Bearer ${created.capability}`)
      .expect(200);
    const rotated = rotatedResponse.body as { joinCode: string };

    expect(rotated.joinCode).not.toBe(created.joinCode);
    await request(server)
      .post('/v1/events/join')
      .send({ joinCode: created.joinCode, displayName: 'Jordan' })
      .expect(404);
    await request(server)
      .post('/v1/events/join')
      .send({ joinCode: rotated.joinCode, displayName: 'Jordan' })
      .expect(200);
    await request(server)
      .get(`/v1/events/${created.event.id}`)
      .set('Authorization', `Bearer ${guest.capability}`)
      .expect(200);
  });

  it('registers and rotates an event-scoped ActivityKit push token', async () => {
    const created = (
      await request(server)
        .post('/v1/events')
        .send({ name: 'Live lock screen', displayName: 'Casey' })
        .expect(201)
    ).body as HostEventAccessBody;
    const endpoint = `/v1/events/${created.event.id}/live-activity-token`;

    await request(server)
      .post(endpoint)
      .send({ pushToken: 'aabbccdd' })
      .expect(401);
    await request(server)
      .post(endpoint)
      .set('Authorization', `Bearer ${created.capability}`)
      .send({ pushToken: 'not-hex' })
      .expect(400);
    await request(server)
      .post(endpoint)
      .set('Authorization', `Bearer ${created.capability}`)
      .send({ pushToken: 'AABBCCDD' })
      .expect(204);
    await request(server)
      .post(endpoint)
      .set('Authorization', `Bearer ${created.capability}`)
      .send({ pushToken: '00112233' })
      .expect(204);

    const member = await prisma.eventMember.findUnique({
      where: { id: created.event.viewer.memberId },
      select: { liveActivityToken: true },
    });
    expect(member?.liveActivityToken).toBe('00112233');
  });

  it('exchanges a one-time transfer and revokes old host authority', async () => {
    const created = (
      await request(server)
        .post('/v1/events')
        .send({ name: 'Host transfer', displayName: 'Morgan' })
        .expect(201)
    ).body as HostEventAccessBody;

    const transferResponse = await request(server)
      .post(`/v1/events/${created.event.id}/host-transfer`)
      .set('Authorization', `Bearer ${created.capability}`)
      .expect(200);
    const transfer = transferResponse.body as {
      transferToken: string;
      expiresAt: string;
    };
    expect(transfer.transferToken).toMatch(/^pdt_/);

    const exchangedResponse = await request(server)
      .post('/v1/host-transfers/exchange')
      .send({ transferToken: transfer.transferToken })
      .expect(200);
    const exchanged = exchangedResponse.body as EventAccessBody;
    expect(exchanged.event.viewer.role).toBe('HOST');
    expect(exchanged.capability).not.toBe(created.capability);

    await request(server)
      .post('/v1/host-transfers/exchange')
      .send({ transferToken: transfer.transferToken })
      .expect(404);
    await request(server)
      .get(`/v1/events/${created.event.id}`)
      .set('Authorization', `Bearer ${created.capability}`)
      .expect(401);
    await request(server)
      .post(`/v1/events/${created.event.id}/rotate-code`)
      .set('Authorization', `Bearer ${exchanged.capability}`)
      .expect(200);
  });

  it('ends idempotently, preserves admitted uploads, restricts new ones, and moderates guests', async () => {
    const host = (
      await request(server)
        .post('/v1/events')
        .send({ name: 'Lifecycle contract', displayName: 'Jamie' })
        .expect(201)
    ).body as HostEventAccessBody;
    const guest = (
      await request(server)
        .post('/v1/events/join')
        .send({ joinCode: host.joinCode, displayName: 'Riley' })
        .expect(200)
    ).body as EventAccessBody;
    const eventPath = `/v1/events/${host.event.id}`;

    await request(server)
      .post(`${eventPath}/end`)
      .set('Authorization', `Bearer ${guest.capability}`)
      .expect(403);
    await request(server)
      .post(`${eventPath}/restrict-uploads`)
      .set('Authorization', `Bearer ${host.capability}`)
      .expect(409);

    const ended = (
      await request(server)
        .post(`${eventPath}/end`)
        .set('Authorization', `Bearer ${host.capability}`)
        .expect(200)
    ).body as EventSnapshotBody;
    expect(ended.state).toBe('ENDED');
    expect(ended.endedAt).not.toBeNull();
    expect(ended.expiresAt).not.toBeNull();
    expect(
      new Date(ended.expiresAt!).getTime() - new Date(ended.endedAt!).getTime(),
    ).toBe(7 * 24 * 60 * 60 * 1_000);

    const endedAgain = (
      await request(server)
        .post(`${eventPath}/end`)
        .set('Authorization', `Bearer ${host.capability}`)
        .expect(200)
    ).body as EventSnapshotBody;
    expect(endedAgain.endedAt).toBe(ended.endedAt);
    expect(endedAgain.expiresAt).toBe(ended.expiresAt);

    const admitted = (
      await request(server)
        .post(`${eventPath}/photos/reservations`)
        .set('Authorization', `Bearer ${guest.capability}`)
        .send(photoReservation())
        .expect(201)
    ).body as { photoId: string };

    const restricted = (
      await request(server)
        .post(`${eventPath}/restrict-uploads`)
        .set('Authorization', `Bearer ${host.capability}`)
        .expect(200)
    ).body as EventSnapshotBody;
    expect(restricted.uploadsRestrictedAt).not.toBeNull();

    await request(server)
      .post(`${eventPath}/photos/${admitted.photoId}/upload-session`)
      .set('Authorization', `Bearer ${guest.capability}`)
      .expect(200);
    await request(server)
      .post(`${eventPath}/photos/reservations`)
      .set('Authorization', `Bearer ${guest.capability}`)
      .send(photoReservation())
      .expect(409);

    await request(server)
      .get(`${eventPath}/members`)
      .set('Authorization', `Bearer ${guest.capability}`)
      .expect(403);
    const members = (
      await request(server)
        .get(`${eventPath}/members`)
        .set('Authorization', `Bearer ${host.capability}`)
        .expect(200)
    ).body as Array<{
      id: string;
      displayName: string;
      role: 'HOST' | 'GUEST';
      isViewer: boolean;
    }>;
    expect(members).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          displayName: 'Jamie',
          role: 'HOST',
          isViewer: true,
        }),
        expect.objectContaining({
          id: guest.event.viewer.memberId,
          displayName: 'Riley',
          role: 'GUEST',
          isViewer: false,
        }),
      ]),
    );

    const renamedGuest = (
      await request(server)
        .patch(`${eventPath}/members/me`)
        .set('Authorization', `Bearer ${guest.capability}`)
        .send({ displayName: 'Riley Updated' })
        .expect(200)
    ).body as EventSnapshotBody;
    expect(renamedGuest.hostDisplayName).toBe('Jamie');

    const renamedHost = (
      await request(server)
        .patch(`${eventPath}/members/me`)
        .set('Authorization', `Bearer ${host.capability}`)
        .send({ displayName: 'Jamie Updated' })
        .expect(200)
    ).body as EventSnapshotBody;
    expect(renamedHost.hostDisplayName).toBe('Jamie Updated');

    const renamedMembers = (
      await request(server)
        .get(`${eventPath}/members`)
        .set('Authorization', `Bearer ${host.capability}`)
        .expect(200)
    ).body as Array<{ id: string; displayName: string }>;
    expect(renamedMembers).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: guest.event.viewer.memberId,
          displayName: 'Riley Updated',
        }),
      ]),
    );

    await request(server)
      .patch(`${eventPath}/members/me`)
      .set('Authorization', `Bearer ${guest.capability}`)
      .send({ displayName: '   ' })
      .expect(400);

    await request(server)
      .delete(`${eventPath}/members/${host.event.viewer.memberId}`)
      .set('Authorization', `Bearer ${host.capability}`)
      .expect(404);
    await request(server)
      .delete(`${eventPath}/members/${guest.event.viewer.memberId}`)
      .set('Authorization', `Bearer ${host.capability}`)
      .expect(204);
    await request(server)
      .get(eventPath)
      .set('Authorization', `Bearer ${guest.capability}`)
      .expect(401);
  });

  it('serializes upload restriction against reservation without canceling the winner', async () => {
    for (let attempt = 0; attempt < 4; attempt += 1) {
      const host = (
        await request(server)
          .post('/v1/events')
          .send({
            name: `Restriction race ${attempt}`,
            displayName: 'Race Host',
          })
          .expect(201)
      ).body as HostEventAccessBody;
      const guest = (
        await request(server)
          .post('/v1/events/join')
          .send({ joinCode: host.joinCode, displayName: 'Race Guest' })
          .expect(200)
      ).body as EventAccessBody;
      const eventPath = `/v1/events/${host.event.id}`;

      await request(server)
        .post(`${eventPath}/end`)
        .set('Authorization', `Bearer ${host.capability}`)
        .expect(200);

      const [restriction, reservation] = await Promise.all([
        request(server)
          .post(`${eventPath}/restrict-uploads`)
          .set('Authorization', `Bearer ${host.capability}`),
        request(server)
          .post(`${eventPath}/photos/reservations`)
          .set('Authorization', `Bearer ${guest.capability}`)
          .send(photoReservation()),
      ]);
      expect(restriction.status).toBe(200);
      expect([201, 409]).toContain(reservation.status);

      if (reservation.status === 201) {
        const admitted = reservation.body as { photoId: string };
        await request(server)
          .post(`${eventPath}/photos/${admitted.photoId}/upload-session`)
          .set('Authorization', `Bearer ${guest.capability}`)
          .expect(200);
      }

      await request(server)
        .post(`${eventPath}/photos/reservations`)
        .set('Authorization', `Bearer ${guest.capability}`)
        .send(photoReservation())
        .expect(409);
    }
  });
});

function photoReservation() {
  return {
    contentType: 'image/jpeg',
    byteSize: 1_024,
    sha256: 'a'.repeat(64),
    width: 100,
    height: 100,
    orientation: 1,
  };
}

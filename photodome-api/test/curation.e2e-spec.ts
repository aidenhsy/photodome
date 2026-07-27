import { Storage } from '@google-cloud/storage';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/common/bootstrap/configure-app';
import { PrismaService } from '../src/common/prisma/prisma.service';

interface EventAccessBody {
  event: {
    id: string;
    viewer: { memberId: string };
  };
  capability: string;
}

interface HostAccessBody extends EventAccessBody {
  joinCode: string;
}

describe('Private curation and original download (e2e)', () => {
  let app: INestApplication;
  let server: Server;
  let prisma: PrismaService;
  const storage = new Storage({
    projectId: 'photodome-test',
    apiEndpoint: 'http://127.0.0.1:4443',
    useAuthWithCustomEndpoint: false,
  });

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

  it('keeps member decisions private and signs only each requested original set', async () => {
    const host = (
      await request(server)
        .post('/v1/events')
        .send({ name: 'Private take-home', displayName: 'Curation Host' })
        .expect(201)
    ).body as HostAccessBody;
    const guestOne = (
      await request(server)
        .post('/v1/events/join')
        .set('X-PhotoDome-Installation-ID', 'curation-guest-one')
        .send({ joinCode: host.joinCode, displayName: 'First Guest' })
        .expect(200)
    ).body as EventAccessBody;
    const guestTwo = (
      await request(server)
        .post('/v1/events/join')
        .set('X-PhotoDome-Installation-ID', 'curation-guest-two')
        .send({ joinCode: host.joinCode, displayName: 'Second Guest' })
        .expect(200)
    ).body as EventAccessBody;
    const path = `/v1/events/${host.event.id}`;

    const livePhoto = await createReadyPhoto(
      prisma,
      storage,
      host.event.id,
      host.event.viewer.memberId,
      'live',
      9,
    );
    const liveDownload = await manifest(
      server,
      path,
      guestOne.capability,
      'all',
      livePhoto,
    );
    expect(liveDownload.photos.map((photo) => photo.id)).toEqual([livePhoto]);

    const liveGuestPhoto = await createReadyPhoto(
      prisma,
      storage,
      host.event.id,
      guestOne.event.viewer.memberId,
      'live-guest',
      10,
    );
    const liveHostDownload = await manifest(
      server,
      path,
      host.capability,
      'all',
    );
    expect(liveHostDownload.photos.map((photo) => photo.id)).toEqual([
      liveGuestPhoto,
    ]);

    const liveGuestDownload = await manifest(
      server,
      path,
      guestOne.capability,
      'all',
    );
    expect(liveGuestDownload.photos.map((photo) => photo.id)).toEqual([
      livePhoto,
    ]);

    const liveReview = (
      await request(server)
        .get(`${path}/selections/review`)
        .set('Authorization', `Bearer ${guestOne.capability}`)
        .expect(200)
    ).body as { photos: Array<{ id: string }> };
    expect(liveReview.photos.map((photo) => photo.id)).toEqual([livePhoto]);

    await setSelection(server, path, guestOne.capability, livePhoto, 'KEEP');
    const liveKept = await manifest(server, path, guestOne.capability, 'kept');
    expect(liveKept.photos.map((photo) => photo.id)).toEqual([livePhoto]);

    await request(server)
      .delete(`${path}/photos/${liveGuestPhoto}`)
      .set('Authorization', `Bearer ${guestOne.capability}`)
      .expect(204);
    await request(server)
      .delete(`${path}/photos/${livePhoto}`)
      .set('Authorization', `Bearer ${host.capability}`)
      .expect(204);

    await request(server)
      .post(`${path}/end`)
      .set('Authorization', `Bearer ${host.capability}`)
      .expect(200);

    const photoIds = await Promise.all(
      ['one', 'two', 'three'].map((name, index) =>
        createReadyPhoto(
          prisma,
          storage,
          host.event.id,
          host.event.viewer.memberId,
          name,
          index,
        ),
      ),
    );
    const [photoOne, photoTwo, photoThree] = photoIds;
    const guestOnePhoto = await createReadyPhoto(
      prisma,
      storage,
      host.event.id,
      guestOne.event.viewer.memberId,
      'guest-one',
      4,
    );

    await setSelection(server, path, guestOne.capability, photoOne!, 'KEEP');
    await setSelection(server, path, guestOne.capability, photoTwo!, 'SKIP');
    await setSelection(server, path, guestTwo.capability, photoTwo!, 'KEEP');
    await request(server)
      .put(`${path}/selections/${guestOnePhoto}`)
      .set('Authorization', `Bearer ${guestOne.capability}`)
      .send({ decision: 'KEEP' })
      .expect(404);

    const oneReview = (
      await request(server)
        .get(`${path}/selections/review`)
        .set('Authorization', `Bearer ${guestOne.capability}`)
        .expect(200)
    ).body as {
      photos: Array<{ id: string }>;
      readyPhotoCount: number;
      decidedPhotoCount: number;
      keptPhotoCount: number;
    };
    expect(oneReview.photos.map((photo) => photo.id)).toEqual([photoThree]);
    expect(oneReview).toMatchObject({
      readyPhotoCount: 3,
      decidedPhotoCount: 2,
      keptPhotoCount: 1,
    });

    const twoReview = (
      await request(server)
        .get(`${path}/selections/review`)
        .set('Authorization', `Bearer ${guestTwo.capability}`)
        .expect(200)
    ).body as { photos: Array<{ id: string }> };
    expect(twoReview.photos.map((photo) => photo.id)).toEqual([
      photoOne,
      photoThree,
      guestOnePhoto,
    ]);

    const oneKept = await manifest(server, path, guestOne.capability, 'kept');
    const twoKept = await manifest(server, path, guestTwo.capability, 'kept');
    expect(oneKept.photos.map((photo) => photo.id)).toEqual([photoOne]);
    expect(twoKept.photos.map((photo) => photo.id)).toEqual([photoTwo]);

    const all = await manifest(server, path, guestOne.capability, 'all');
    expect(all.totalPhotoCount).toBe(3);
    expect(all.photos).toHaveLength(3);
    expect(all.photos.map((photo) => photo.id)).not.toContain(guestOnePhoto);

    const ownPhoto = await manifest(
      server,
      path,
      guestOne.capability,
      'all',
      guestOnePhoto,
    );
    expect(ownPhoto.totalPhotoCount).toBe(1);
    expect(ownPhoto.photos.map((photo) => photo.id)).toEqual([guestOnePhoto]);

    const guestTwoAll = await manifest(
      server,
      path,
      guestTwo.capability,
      'all',
    );
    expect(guestTwoAll.totalPhotoCount).toBe(4);
    expect(guestTwoAll.photos.map((photo) => photo.id)).toContain(
      guestOnePhoto,
    );
    const originalResponse = await fetch(
      all.photos.find((photo) => photo.id === photoOne)!.originalUrl,
    );
    expect(originalResponse.ok).toBe(true);
    expect(await originalResponse.text()).toBe('original-one');

    const undo = (
      await request(server)
        .delete(`${path}/selections/latest`)
        .set('Authorization', `Bearer ${guestOne.capability}`)
        .expect(200)
    ).body as { selection: { photoId: string; decision: string } };
    expect(undo.selection).toMatchObject({
      photoId: photoTwo,
      decision: 'SKIP',
    });
    const afterUndo = (
      await request(server)
        .get(`${path}/selections/review`)
        .set('Authorization', `Bearer ${guestOne.capability}`)
        .expect(200)
    ).body as { photos: Array<{ id: string }> };
    expect(afterUndo.photos.map((photo) => photo.id)).toEqual([
      photoTwo,
      photoThree,
    ]);

    await request(server)
      .delete(`${path}/photos/${guestOnePhoto}`)
      .set('Authorization', `Bearer ${host.capability}`)
      .expect(404);
    await request(server)
      .delete(`${path}/photos/${guestOnePhoto}`)
      .set('Authorization', `Bearer ${guestOne.capability}`)
      .expect(204);

    await request(server)
      .delete(`${path}/photos/${photoOne}`)
      .set('Authorization', `Bearer ${host.capability}`)
      .expect(204);
    const keptAfterRemoval = await manifest(
      server,
      path,
      guestOne.capability,
      'kept',
    );
    expect(keptAfterRemoval.photos).toHaveLength(0);
  });
});

async function setSelection(
  server: Server,
  path: string,
  capability: string,
  photoId: string,
  decision: 'KEEP' | 'SKIP',
): Promise<void> {
  await request(server)
    .put(`${path}/selections/${photoId}`)
    .set('Authorization', `Bearer ${capability}`)
    .send({ decision })
    .expect(200);
}

async function manifest(
  server: Server,
  path: string,
  capability: string,
  mode: 'all' | 'kept',
  photoId?: string,
): Promise<{
  photos: Array<{ id: string; originalUrl: string }>;
  totalPhotoCount: number;
}> {
  return (
    await request(server)
      .get(`${path}/download-manifest`)
      .query({ mode, ...(photoId ? { photoId } : {}) })
      .set('Authorization', `Bearer ${capability}`)
      .expect(200)
  ).body as {
    photos: Array<{ id: string; originalUrl: string }>;
    totalPhotoCount: number;
  };
}

async function createReadyPhoto(
  prisma: PrismaService,
  storage: Storage,
  eventId: string,
  contributorMemberId: string,
  name: string,
  index: number,
): Promise<string> {
  const photoId = randomUUID();
  const prefix = `events/${eventId}/photos/${photoId}`;
  const originalKey = `${prefix}/original.jpg`;
  await Promise.all([
    storage
      .bucket('photodome-media-dev')
      .file(originalKey)
      .save(Buffer.from(`original-${name}`), {
        contentType: 'image/jpeg',
      }),
    storage
      .bucket('photodome-media-dev')
      .file(`${prefix}/display.jpg`)
      .save(Buffer.from(`display-${name}`), {
        contentType: 'image/jpeg',
      }),
    storage
      .bucket('photodome-media-dev')
      .file(`${prefix}/thumb.jpg`)
      .save(Buffer.from(`thumb-${name}`), {
        contentType: 'image/jpeg',
      }),
  ]);
  await prisma.photo.create({
    data: {
      id: photoId,
      eventId,
      contributorMemberId,
      state: 'READY',
      originalKey,
      displayKey: `${prefix}/display.jpg`,
      thumbKey: `${prefix}/thumb.jpg`,
      contentType: 'image/jpeg',
      byteSize: Buffer.byteLength(`original-${name}`),
      sha256: index.toString(16).padStart(64, '0'),
      width: 100,
      height: 100,
      orientation: 1,
      admittedBeforeRestriction: true,
      uploadedAt: new Date(1_800_000_000_000 + index),
      readyAt: new Date(1_800_000_000_000 + index),
    },
  });
  return photoId;
}

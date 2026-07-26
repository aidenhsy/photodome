import { createHash, randomUUID } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import {
  EventMemberRole,
  EventState,
  PhotoSelectionDecision,
  PhotoState,
} from '@prisma/client';
import { PrismaService } from '../src/common/prisma/prisma.service';
import { PrismaCurationRepository } from '../src/modules/curation/infrastructure/prisma-curation.repository';
import { PrismaEventRepository } from '../src/modules/events/infrastructure/prisma-event.repository';
import { EventCapacityError } from '../src/modules/events/domain/event.errors';
import { PrismaPhotoRepository } from '../src/modules/media/infrastructure/prisma-photo.repository';
import { PhotoCapacityError } from '../src/modules/media/domain/media.errors';

const MEMBER_COUNT = 100;
const PHOTO_COUNT = 2_000;
const SELECTION_COUNT = 1_000;
const ITERATIONS = 25;

const budgets = {
  snapshotP95Ms: Number(process.env.SCALE_SNAPSHOT_P95_MS ?? '250'),
  albumPageP95Ms: Number(process.env.SCALE_ALBUM_PAGE_P95_MS ?? '500'),
  reviewPageP95Ms: Number(process.env.SCALE_REVIEW_PAGE_P95_MS ?? '750'),
  manifestPageP95Ms: Number(process.env.SCALE_MANIFEST_PAGE_P95_MS ?? '500'),
  cascadePurgeMs: Number(process.env.SCALE_CASCADE_PURGE_MS ?? '5000'),
};

async function verify(): Promise<void> {
  const databaseUrl =
    process.env.TEST_DATABASE_URL ??
    'postgresql://photodome:photodome@localhost:5434/photodome_test?schema=public';
  const databaseName = new URL(databaseUrl).pathname.slice(1);
  if (databaseName !== 'photodome_test') {
    throw new Error('Scale validation may only target photodome_test');
  }

  const prisma = new PrismaService({
    datasources: { db: { url: databaseUrl } },
  });
  const events = new PrismaEventRepository(prisma);
  const photos = new PrismaPhotoRepository(prisma);
  const curation = new PrismaCurationRepository(prisma);
  const eventId = randomUUID();
  const hostMemberId = randomUUID();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1_000);

  try {
    await prisma.event.create({
      data: {
        id: eventId,
        name: 'M6 scale validation',
        hostDisplayName: 'Scale Host',
        state: EventState.ENDED,
        joinCodeHash: hash(`join-${eventId}`),
        endedAt: now,
        expiresAt,
        members: {
          create: {
            id: hostMemberId,
            role: EventMemberRole.HOST,
            displayName: 'Scale Host',
            capabilityHash: hash(`host-${eventId}`),
          },
        },
      },
    });
    await prisma.eventMember.createMany({
      data: Array.from({ length: MEMBER_COUNT - 1 }, (_, index) => ({
        id: randomUUID(),
        eventId,
        role: EventMemberRole.GUEST,
        displayName: `Guest ${index + 1}`,
        capabilityHash: hash(`guest-${eventId}-${index}`),
      })),
    });
    const photoRows = Array.from({ length: PHOTO_COUNT }, (_, index) => {
      const id = randomUUID();
      const prefix = `events/${eventId}/photos/${id}`;
      return {
        id,
        eventId,
        contributorMemberId: hostMemberId,
        state: PhotoState.READY,
        originalKey: `${prefix}/original.jpg`,
        displayKey: `${prefix}/display.jpg`,
        thumbKey: `${prefix}/thumb.jpg`,
        contentType: 'image/jpeg',
        byteSize: 2_000_000,
        sha256: hash(`photo-${id}`),
        width: 4_032,
        height: 3_024,
        capturedAt: now,
        orientation: 1,
        admittedBeforeRestriction: true,
        reservedAt: now,
        uploadedAt: now,
        readyAt: new Date(now.getTime() + index),
      };
    });
    for (let offset = 0; offset < photoRows.length; offset += 500) {
      await prisma.photo.createMany({
        data: photoRows.slice(offset, offset + 500),
      });
    }
    await prisma.photoSelection.createMany({
      data: photoRows.slice(0, SELECTION_COUNT).map((photo, index) => ({
        eventId,
        memberId: hostMemberId,
        photoId: photo.id,
        decision: PhotoSelectionDecision.KEEP,
        decidedAt: new Date(now.getTime() + index),
      })),
    });

    await expectError(
      () =>
        events.joinEvent({
          joinCodeHash: hash(`join-${eventId}`),
          guestDisplayName: 'Overflow Guest',
          guestCapabilityHash: hash(`overflow-${eventId}`),
        }),
      EventCapacityError,
      '101st attendee was admitted',
    );
    await expectError(
      () =>
        photos.reserve({
          id: randomUUID(),
          eventId,
          contributorMemberId: hostMemberId,
          originalKey: `events/${eventId}/overflow/original.jpg`,
          displayKey: `events/${eventId}/overflow/display.jpg`,
          thumbKey: `events/${eventId}/overflow/thumb.jpg`,
          contentType: 'image/jpeg',
          byteSize: 1,
          sha256: hash('overflow'),
          width: 1,
          height: 1,
          capturedAt: now,
          orientation: 1,
          now,
        }),
      PhotoCapacityError,
      '2,001st photo was admitted',
    );

    const snapshotP95Ms = await p95(() =>
      events.getSnapshot(eventId, hostMemberId),
    );
    const albumPageP95Ms = await p95(() =>
      photos.listReady(eventId, null, 100),
    );
    const reviewPageP95Ms = await p95(() =>
      curation.reviewPage({
        eventId,
        memberId: hostMemberId,
        cursor: null,
        limit: 100,
        now,
      }),
    );
    const manifestPageP95Ms = await p95(() =>
      curation.manifestPage({
        eventId,
        memberId: hostMemberId,
        mode: 'KEPT',
        cursor: null,
        limit: 100,
        photoId: null,
        allowLive: false,
        now,
      }),
    );
    const purgeStartedAt = performance.now();
    await prisma.event.delete({ where: { id: eventId } });
    const cascadePurgeMs = performance.now() - purgeStartedAt;

    const measurements = {
      members: MEMBER_COUNT,
      photos: PHOTO_COUNT,
      selections: SELECTION_COUNT,
      iterations: ITERATIONS,
      snapshotP95Ms,
      albumPageP95Ms,
      reviewPageP95Ms,
      manifestPageP95Ms,
      cascadePurgeMs,
      budgets,
    };
    assertBudget('snapshot p95', snapshotP95Ms, budgets.snapshotP95Ms);
    assertBudget('album page p95', albumPageP95Ms, budgets.albumPageP95Ms);
    assertBudget('review page p95', reviewPageP95Ms, budgets.reviewPageP95Ms);
    assertBudget(
      'manifest page p95',
      manifestPageP95Ms,
      budgets.manifestPageP95Ms,
    );
    assertBudget('cascade purge', cascadePurgeMs, budgets.cascadePurgeMs);
    process.stdout.write(`${JSON.stringify(measurements, null, 2)}\n`);
  } finally {
    await prisma.event.deleteMany({ where: { id: eventId } });
    await prisma.eventCleanupTombstone.deleteMany({ where: { eventId } });
    await prisma.$disconnect();
  }
}

async function p95(operation: () => Promise<unknown>): Promise<number> {
  await operation();
  const durations: number[] = [];
  for (let index = 0; index < ITERATIONS; index += 1) {
    const startedAt = performance.now();
    await operation();
    durations.push(performance.now() - startedAt);
  }
  durations.sort((left, right) => left - right);
  return durations[Math.ceil(durations.length * 0.95) - 1] ?? 0;
}

async function expectError(
  operation: () => Promise<unknown>,
  expected: new () => Error,
  message: string,
): Promise<void> {
  try {
    await operation();
  } catch (error) {
    if (error instanceof expected) {
      return;
    }
    throw error;
  }
  throw new Error(message);
}

function assertBudget(
  label: string,
  actualMs: number,
  maximumMs: number,
): void {
  if (actualMs > maximumMs) {
    throw new Error(
      `${label} exceeded local M6 budget: ${actualMs.toFixed(2)}ms > ${maximumMs}ms`,
    );
  }
}

function hash(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

void verify().catch((error: unknown) => {
  process.stderr.write(
    `${error instanceof Error ? error.message : String(error)}\n`,
  );
  process.exitCode = 1;
});

import { Injectable } from '@nestjs/common';
import { EventState, PhotoState } from '@prisma/client';
import { PrismaService } from '../../../common/prisma/prisma.service';
import type { ExpiryRepository } from '../application/ports/expiry.repository';
import type { CleanupBacklog, CleanupTarget } from '../domain/expiry';

@Injectable()
export class PrismaExpiryRepository implements ExpiryRepository {
  constructor(private readonly prisma: PrismaService) {}

  async markExpiring(
    eventId: string,
    now: Date,
  ): Promise<CleanupTarget | null> {
    return this.prisma.$transaction(async (transaction) => {
      const event = await transaction.event.findUnique({
        where: { id: eventId },
        select: { id: true, state: true, expiresAt: true },
      });
      const existingTombstone =
        await transaction.eventCleanupTombstone.findUnique({
          where: { eventId },
        });

      if (!event) {
        return existingTombstone
          ? {
              eventId,
              prefix: existingTombstone.prefix,
              hadEvent: false,
            }
          : null;
      }
      if (
        event.state !== EventState.EXPIRING &&
        (!event.expiresAt || event.expiresAt > now)
      ) {
        return null;
      }

      if (event.state !== EventState.EXPIRING) {
        await transaction.event.update({
          where: { id: eventId },
          data: { state: EventState.EXPIRING },
        });
        await transaction.photo.updateMany({
          where: {
            eventId,
            state: { not: PhotoState.REMOVED },
          },
          data: { state: PhotoState.EXPIRED },
        });
      }

      const prefix = `events/${eventId}/`;
      await transaction.eventCleanupTombstone.upsert({
        where: { eventId },
        create: { eventId, prefix },
        update: { prefix },
      });
      return { eventId, prefix, hadEvent: true };
    });
  }

  async beginAttempt(eventId: string, now: Date): Promise<number> {
    const tombstone = await this.prisma.eventCleanupTombstone.update({
      where: { eventId },
      data: {
        attemptCount: { increment: 1 },
        lastAttemptAt: now,
        lastError: null,
      },
      select: { attemptCount: true },
    });
    return tombstone.attemptCount;
  }

  async recordFailure(
    eventId: string,
    error: string,
    attemptedAt: Date,
  ): Promise<void> {
    await this.prisma.eventCleanupTombstone.updateMany({
      where: { eventId },
      data: {
        lastAttemptAt: attemptedAt,
        lastError: error.slice(0, 500),
      },
    });
  }

  async finalize(eventId: string): Promise<void> {
    await this.prisma.$transaction(async (transaction) => {
      await transaction.event.deleteMany({ where: { id: eventId } });
      await transaction.eventCleanupTombstone.deleteMany({
        where: { eventId },
      });
    });
  }

  async listDueEventIds(now: Date, limit: number): Promise<string[]> {
    const events = await this.prisma.event.findMany({
      where: {
        OR: [{ state: EventState.EXPIRING }, { expiresAt: { lte: now } }],
      },
      orderBy: [{ expiresAt: 'asc' }, { id: 'asc' }],
      take: limit,
      select: { id: true },
    });
    return events.map((event) => event.id);
  }

  async listTombstonedEventIds(limit: number): Promise<string[]> {
    const tombstones = await this.prisma.eventCleanupTombstone.findMany({
      orderBy: [{ createdAt: 'asc' }, { eventId: 'asc' }],
      take: limit,
      select: { eventId: true },
    });
    return tombstones.map((tombstone) => tombstone.eventId);
  }

  async findExistingEventIds(eventIds: string[]): Promise<Set<string>> {
    if (eventIds.length === 0) {
      return new Set();
    }
    const events = await this.prisma.event.findMany({
      where: { id: { in: eventIds } },
      select: { id: true },
    });
    return new Set(events.map((event) => event.id));
  }

  async ensureOrphanTombstone(eventId: string): Promise<boolean> {
    return this.prisma.$transaction(async (transaction) => {
      const event = await transaction.event.findUnique({
        where: { id: eventId },
        select: { id: true },
      });
      if (event) {
        return false;
      }
      const inserted = await transaction.eventCleanupTombstone.createMany({
        data: {
          eventId,
          prefix: `events/${eventId}/`,
        },
        skipDuplicates: true,
      });
      return inserted.count === 1;
    });
  }

  async cleanupBacklog(now: Date): Promise<CleanupBacklog> {
    const [overdueEvents, tombstones] = await Promise.all([
      this.prisma.event.findMany({
        where: {
          OR: [{ state: EventState.EXPIRING }, { expiresAt: { lte: now } }],
        },
        select: { id: true, expiresAt: true, updatedAt: true },
      }),
      this.prisma.eventCleanupTombstone.findMany({
        select: { eventId: true, createdAt: true },
      }),
    ]);
    const cleanupIds = new Set([
      ...overdueEvents.map((event) => event.id),
      ...tombstones.map((tombstone) => tombstone.eventId),
    ]);
    const candidates = [
      ...overdueEvents.map((event) => event.expiresAt ?? event.updatedAt),
      ...tombstones.map((tombstone) => tombstone.createdAt),
    ];
    const oldest = candidates.sort(
      (left, right) => left.getTime() - right.getTime(),
    )[0];
    return {
      overdueEvents: cleanupIds.size,
      oldestOverdueSeconds: oldest
        ? Math.max(0, (now.getTime() - oldest.getTime()) / 1_000)
        : 0,
    };
  }
}

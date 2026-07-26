import { Inject, Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import type { Queue } from 'bullmq';
import {
  OBJECT_STORAGE_GATEWAY,
  type ObjectStorageGateway,
} from '../../media/application/ports/object-storage.gateway';
import {
  EVENT_REALTIME_PUBLISHER,
  type EventRealtimePublisher,
} from '../../realtime/realtime.constants';
import { EVENT_EXPIRY_QUEUE, EXPIRY_REPOSITORY } from './expiry.constants';
import { ExpiryMetricsService } from './expiry-metrics.service';
import type { ExpiryRepository } from './ports/expiry.repository';

const RECONCILIATION_BATCH_SIZE = 500;

@Injectable()
export class EventExpiryService {
  private readonly logger = new Logger(EventExpiryService.name);

  constructor(
    @Inject(EXPIRY_REPOSITORY)
    private readonly expiry: ExpiryRepository,
    @Inject(OBJECT_STORAGE_GATEWAY)
    private readonly storage: ObjectStorageGateway,
    @Inject(EVENT_REALTIME_PUBLISHER)
    private readonly realtime: EventRealtimePublisher,
    @InjectQueue(EVENT_EXPIRY_QUEUE)
    private readonly queue: Queue,
    private readonly metrics: ExpiryMetricsService,
  ) {}

  async schedule(eventId: string, expiresAt: Date): Promise<void> {
    await this.enqueueCleanup(
      eventId,
      Math.max(0, expiresAt.getTime() - Date.now()),
    );
  }

  async cleanup(eventId: string, now: Date = new Date()): Promise<void> {
    const target = await this.expiry.markExpiring(eventId, now);
    if (!target) {
      return;
    }

    const startedAt = Date.now();
    const attempt = await this.expiry.beginAttempt(eventId, now);
    let verificationFailed = false;
    try {
      if (target.hadEvent) {
        await this.realtime.eventExpired(eventId);
      }
      const deleted = await this.storage.deleteEventPrefix(eventId);
      if (await this.storage.eventPrefixObjectsExist(eventId)) {
        verificationFailed = true;
        throw new Error(
          'Event prefix still contains one or more object generations',
        );
      }
      await this.expiry.finalize(eventId);
      const durationSeconds = (Date.now() - startedAt) / 1_000;
      this.metrics.cleanupSucceeded(
        deleted.objectsDeleted,
        deleted.bytesDeleted,
        durationSeconds,
      );
      this.logger.log({
        operation: 'event_cleanup',
        eventId,
        attempt,
        objectsDeleted: deleted.objectsDeleted,
        bytesDeleted: deleted.bytesDeleted,
        durationMs: Date.now() - startedAt,
        outcome: 'success',
      });
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Event cleanup failed';
      await this.expiry.recordFailure(eventId, message, new Date());
      this.metrics.cleanupFailed(
        (Date.now() - startedAt) / 1_000,
        verificationFailed,
      );
      this.logger.error({
        operation: 'event_cleanup',
        eventId,
        attempt,
        durationMs: Date.now() - startedAt,
        outcome: 'failure',
        error: message,
      });
      throw error;
    }
  }

  async reconcile(now: Date = new Date()): Promise<void> {
    try {
      const [dueEventIds, tombstonedEventIds, storedEventIds] =
        await Promise.all([
          this.expiry.listDueEventIds(now, RECONCILIATION_BATCH_SIZE),
          this.expiry.listTombstonedEventIds(RECONCILIATION_BATCH_SIZE),
          this.storage.listStoredEventIds(),
        ]);
      const existingStoredEventIds =
        await this.expiry.findExistingEventIds(storedEventIds);
      const orphanCandidates = storedEventIds.filter(
        (eventId) => !existingStoredEventIds.has(eventId),
      );
      const orphanResults = await Promise.all(
        orphanCandidates.map(async (eventId) => ({
          eventId,
          inserted: await this.expiry.ensureOrphanTombstone(eventId),
        })),
      );
      const orphanEventIds = orphanResults
        .filter(({ inserted }) => inserted)
        .map(({ eventId }) => eventId);
      orphanEventIds.forEach(() => this.metrics.orphanDiscovered());

      const cleanupIds = new Set([
        ...dueEventIds,
        ...tombstonedEventIds,
        ...orphanEventIds,
      ]);
      await Promise.all(
        [...cleanupIds].map((eventId) => this.enqueueCleanup(eventId, 0)),
      );
      this.metrics.reconciliationFinished(true);
      this.logger.log({
        operation: 'event_cleanup_reconciliation',
        dueEvents: dueEventIds.length,
        tombstones: tombstonedEventIds.length,
        storedPrefixes: storedEventIds.length,
        orphanPrefixes: orphanEventIds.length,
        enqueued: cleanupIds.size,
        outcome: 'success',
      });
    } catch (error) {
      this.metrics.reconciliationFinished(false);
      this.logger.error({
        operation: 'event_cleanup_reconciliation',
        outcome: 'failure',
        error: error instanceof Error ? error.message : 'Reconciliation failed',
      });
      throw error;
    }
  }

  private async enqueueCleanup(eventId: string, delay: number): Promise<void> {
    await this.queue.add(
      'cleanup-event',
      { eventId },
      {
        jobId: `event-expiry-${eventId}`,
        delay,
        attempts: 12,
        backoff: { type: 'exponential', delay: 5_000 },
        removeOnComplete: true,
        removeOnFail: true,
      },
    );
  }
}

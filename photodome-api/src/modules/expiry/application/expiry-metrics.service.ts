import { Inject, Injectable } from '@nestjs/common';
import {
  Counter,
  Gauge,
  Histogram,
  Registry,
  collectDefaultMetrics,
} from 'prom-client';
import { EXPIRY_REPOSITORY } from './expiry.constants';
import type { ExpiryRepository } from './ports/expiry.repository';

@Injectable()
export class ExpiryMetricsService {
  private readonly registry = new Registry();
  private readonly attempts = new Counter({
    name: 'photodome_cleanup_attempts_total',
    help: 'Event cleanup attempts by outcome.',
    labelNames: ['outcome'] as const,
    registers: [this.registry],
  });
  private readonly objectsDeleted = new Counter({
    name: 'photodome_cleanup_objects_deleted_total',
    help: 'GCS object generations removed by verified event cleanup.',
    registers: [this.registry],
  });
  private readonly bytesDeleted = new Counter({
    name: 'photodome_cleanup_bytes_deleted_total',
    help: 'GCS bytes removed by verified event cleanup.',
    registers: [this.registry],
  });
  private readonly verificationFailures = new Counter({
    name: 'photodome_cleanup_verification_failures_total',
    help: 'Cleanup attempts where the event prefix was not empty after delete.',
    registers: [this.registry],
  });
  private readonly orphanPrefixes = new Counter({
    name: 'photodome_cleanup_orphan_prefixes_total',
    help: 'GCS event prefixes discovered without matching server metadata.',
    registers: [this.registry],
  });
  private readonly reconciliationRuns = new Counter({
    name: 'photodome_cleanup_reconciliation_runs_total',
    help: 'Expiry reconciliation runs by outcome.',
    labelNames: ['outcome'] as const,
    registers: [this.registry],
  });
  private readonly duration = new Histogram({
    name: 'photodome_cleanup_duration_seconds',
    help: 'Time from cleanup worker start through verified GCS and DB purge.',
    buckets: [0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60],
    registers: [this.registry],
  });
  private readonly overdueEvents = new Gauge({
    name: 'photodome_cleanup_overdue_events',
    help: 'Expired events or cleanup tombstones not yet fully purged.',
    registers: [this.registry],
  });
  private readonly oldestOverdue = new Gauge({
    name: 'photodome_cleanup_oldest_overdue_seconds',
    help: 'Age in seconds of the oldest unclean expired event or tombstone.',
    registers: [this.registry],
  });

  constructor(
    @Inject(EXPIRY_REPOSITORY)
    private readonly expiry: ExpiryRepository,
  ) {
    collectDefaultMetrics({
      register: this.registry,
      prefix: 'photodome_process_',
    });
  }

  cleanupSucceeded(
    objectsDeleted: number,
    bytesDeleted: number,
    durationSeconds: number,
  ): void {
    this.attempts.inc({ outcome: 'success' });
    this.objectsDeleted.inc(objectsDeleted);
    this.bytesDeleted.inc(bytesDeleted);
    this.duration.observe(durationSeconds);
  }

  cleanupFailed(durationSeconds: number, verificationFailed: boolean): void {
    this.attempts.inc({ outcome: 'failure' });
    this.duration.observe(durationSeconds);
    if (verificationFailed) {
      this.verificationFailures.inc();
    }
  }

  orphanDiscovered(): void {
    this.orphanPrefixes.inc();
  }

  reconciliationFinished(succeeded: boolean): void {
    this.reconciliationRuns.inc({
      outcome: succeeded ? 'success' : 'failure',
    });
  }

  async render(now: Date = new Date()): Promise<{
    contentType: string;
    body: string;
  }> {
    const backlog = await this.expiry.cleanupBacklog(now);
    this.overdueEvents.set(backlog.overdueEvents);
    this.oldestOverdue.set(backlog.oldestOverdueSeconds);
    return {
      contentType: this.registry.contentType,
      body: await this.registry.metrics(),
    };
  }
}

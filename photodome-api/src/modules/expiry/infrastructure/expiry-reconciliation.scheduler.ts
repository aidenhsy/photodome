import { Injectable, type OnApplicationBootstrap } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { ConfigService } from '@nestjs/config';
import type { Queue } from 'bullmq';
import type { Environment } from '../../../common/config/env.validation';
import { EVENT_EXPIRY_QUEUE } from '../application/expiry.constants';

@Injectable()
export class ExpiryReconciliationScheduler implements OnApplicationBootstrap {
  constructor(
    @InjectQueue(EVENT_EXPIRY_QUEUE)
    private readonly queue: Queue,
    private readonly config: ConfigService<Environment, true>,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    const intervalSeconds = this.config.get(
      'CLEANUP_RECONCILIATION_INTERVAL_SECONDS',
      { infer: true },
    );
    await this.queue.upsertJobScheduler(
      'expiry-reconciliation',
      { every: intervalSeconds * 1_000 },
      {
        name: 'reconcile-expiry',
        data: {},
        opts: {
          attempts: 5,
          backoff: { type: 'exponential', delay: 5_000 },
          removeOnComplete: 10,
          removeOnFail: 10,
        },
      },
    );
    await this.queue.add(
      'reconcile-expiry',
      {},
      {
        jobId: 'expiry-reconciliation-bootstrap',
        attempts: 5,
        backoff: { type: 'exponential', delay: 5_000 },
        removeOnComplete: true,
        removeOnFail: true,
      },
    );
  }
}

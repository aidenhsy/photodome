import { Processor, WorkerHost } from '@nestjs/bullmq';
import type { Job } from 'bullmq';
import { EventExpiryService } from '../application/event-expiry.service';
import { EVENT_EXPIRY_QUEUE } from '../application/expiry.constants';

interface CleanupEventJob {
  eventId: string;
}

@Processor(EVENT_EXPIRY_QUEUE, { concurrency: 2 })
export class EventExpiryProcessor extends WorkerHost {
  constructor(private readonly expiry: EventExpiryService) {
    super();
  }

  async process(job: Job<CleanupEventJob>): Promise<void> {
    if (job.name === 'reconcile-expiry') {
      await this.expiry.reconcile();
      return;
    }
    if (job.name === 'cleanup-event') {
      await this.expiry.cleanup(job.data.eventId);
    }
  }
}

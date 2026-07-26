import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { MediaModule } from '../media/media.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { EventExpiryService } from './application/event-expiry.service';
import {
  EVENT_EXPIRY_QUEUE,
  EXPIRY_REPOSITORY,
} from './application/expiry.constants';
import { ExpiryMetricsService } from './application/expiry-metrics.service';
import { EventExpiryProcessor } from './infrastructure/event-expiry.processor';
import { ExpiryReconciliationScheduler } from './infrastructure/expiry-reconciliation.scheduler';
import { PrismaExpiryRepository } from './infrastructure/prisma-expiry.repository';
import { MetricsController } from './presentation/metrics.controller';

const workerProviders =
  process.env.DISABLE_BACKGROUND_WORKERS === '1'
    ? []
    : [EventExpiryProcessor, ExpiryReconciliationScheduler];

@Module({
  imports: [
    MediaModule,
    RealtimeModule,
    BullModule.registerQueue({ name: EVENT_EXPIRY_QUEUE }),
  ],
  controllers: [MetricsController],
  providers: [
    EventExpiryService,
    ExpiryMetricsService,
    {
      provide: EXPIRY_REPOSITORY,
      useClass: PrismaExpiryRepository,
    },
    ...workerProviders,
  ],
  exports: [EventExpiryService, ExpiryMetricsService],
})
export class ExpiryModule {}

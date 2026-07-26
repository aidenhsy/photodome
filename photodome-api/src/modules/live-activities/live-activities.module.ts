import { Module } from '@nestjs/common';
import { EventCapabilityGuard } from '../capabilities/presentation/event-capability.guard';
import { EventsModule } from '../events/events.module';
import { EventLiveActivityPublisherService } from './application/event-live-activity-publisher.service';
import { EVENT_LIVE_ACTIVITY_PUBLISHER } from './application/live-activity.constants';
import { LiveActivityApplicationService } from './application/live-activity-application.service';
import { APNS_LIVE_ACTIVITY_GATEWAY } from './application/ports/apns-live-activity.gateway';
import { LIVE_ACTIVITY_REPOSITORY } from './application/ports/live-activity.repository';
import { ApnsHttp2LiveActivityGateway } from './infrastructure/apns-live-activity.gateway';
import { PrismaLiveActivityRepository } from './infrastructure/prisma-live-activity.repository';
import { LiveActivitiesController } from './presentation/live-activities.controller';

@Module({
  imports: [EventsModule],
  controllers: [LiveActivitiesController],
  providers: [
    EventCapabilityGuard,
    LiveActivityApplicationService,
    ApnsHttp2LiveActivityGateway,
    PrismaLiveActivityRepository,
    {
      provide: LIVE_ACTIVITY_REPOSITORY,
      useExisting: PrismaLiveActivityRepository,
    },
    {
      provide: APNS_LIVE_ACTIVITY_GATEWAY,
      useExisting: ApnsHttp2LiveActivityGateway,
    },
    {
      provide: EVENT_LIVE_ACTIVITY_PUBLISHER,
      useClass: EventLiveActivityPublisherService,
    },
  ],
  exports: [EVENT_LIVE_ACTIVITY_PUBLISHER],
})
export class LiveActivitiesModule {}

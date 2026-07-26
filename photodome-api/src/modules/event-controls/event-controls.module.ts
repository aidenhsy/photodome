import { Module } from '@nestjs/common';
import { EventCapabilityGuard } from '../capabilities/presentation/event-capability.guard';
import { EventsModule } from '../events/events.module';
import { LiveActivitiesModule } from '../live-activities/live-activities.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { ExpiryModule } from '../expiry/expiry.module';
import { EventControlsApplicationService } from './application/event-controls-application.service';
import { EventControlsController } from './presentation/event-controls.controller';

@Module({
  imports: [EventsModule, ExpiryModule, LiveActivitiesModule, RealtimeModule],
  controllers: [EventControlsController],
  providers: [EventControlsApplicationService, EventCapabilityGuard],
})
export class EventControlsModule {}

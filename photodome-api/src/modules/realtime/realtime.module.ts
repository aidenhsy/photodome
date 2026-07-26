import { forwardRef, Module } from '@nestjs/common';
import { EventsModule } from '../events/events.module';
import { EventGateway } from './event.gateway';
import { EVENT_REALTIME_PUBLISHER } from './realtime.constants';

@Module({
  imports: [forwardRef(() => EventsModule)],
  providers: [
    EventGateway,
    {
      provide: EVENT_REALTIME_PUBLISHER,
      useExisting: EventGateway,
    },
  ],
  exports: [EVENT_REALTIME_PUBLISHER],
})
export class RealtimeModule {}

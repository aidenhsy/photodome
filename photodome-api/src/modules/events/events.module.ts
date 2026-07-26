import { forwardRef, Module } from '@nestjs/common';
import { CapabilitiesModule } from '../capabilities/capabilities.module';
import { EventCapabilityGuard } from '../capabilities/presentation/event-capability.guard';
import { EventApplicationService } from './application/event-application.service';
import { EventAccessAuthorizer } from './application/event-access-authorizer';
import { EVENT_REPOSITORY } from './application/ports/event.repository';
import { PrismaEventRepository } from './infrastructure/prisma-event.repository';
import { EventsPrivateController } from './presentation/events-private.controller';
import { EventsPublicController } from './presentation/events-public.controller';
import { HostTransfersController } from './presentation/host-transfers.controller';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [CapabilitiesModule, forwardRef(() => RealtimeModule)],
  controllers: [
    EventsPublicController,
    EventsPrivateController,
    HostTransfersController,
  ],
  providers: [
    EventApplicationService,
    EventAccessAuthorizer,
    EventCapabilityGuard,
    {
      provide: EVENT_REPOSITORY,
      useClass: PrismaEventRepository,
    },
  ],
  exports: [EventApplicationService, EventAccessAuthorizer, EVENT_REPOSITORY],
})
export class EventsModule {}

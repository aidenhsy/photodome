import { Module } from '@nestjs/common';
import { EventCapabilityGuard } from '../capabilities/presentation/event-capability.guard';
import { EventsModule } from '../events/events.module';
import { MediaModule } from '../media/media.module';
import { CurationApplicationService } from './application/curation-application.service';
import { CURATION_REPOSITORY } from './application/ports/curation.repository';
import { PrismaCurationRepository } from './infrastructure/prisma-curation.repository';
import { CurationController } from './presentation/curation.controller';

@Module({
  imports: [EventsModule, MediaModule],
  controllers: [CurationController],
  providers: [
    CurationApplicationService,
    EventCapabilityGuard,
    {
      provide: CURATION_REPOSITORY,
      useClass: PrismaCurationRepository,
    },
  ],
})
export class CurationModule {}

import {
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { EventAccess } from '../../capabilities/domain/capability';
import { CurrentEventAccess } from '../../capabilities/presentation/current-event-access.decorator';
import { EventCapabilityGuard } from '../../capabilities/presentation/event-capability.guard';
import { RequireEventRole } from '../../capabilities/presentation/require-event-role.decorator';
import { EventApplicationService } from '../application/event-application.service';
import { EventSnapshotDto } from './dto/event.dto';
import { CreateHostTransferResponseDto } from './dto/host-transfer.dto';
import { EventDomainExceptionFilter } from './event-domain-exception.filter';

@ApiTags('events')
@ApiBearerAuth('eventCapability')
@Controller('events/:eventId')
@UseGuards(EventCapabilityGuard)
@UseFilters(EventDomainExceptionFilter)
export class EventsPrivateController {
  constructor(private readonly events: EventApplicationService) {}

  @Get()
  @ApiOperation({
    operationId: 'getEvent',
    summary: 'Get the authorized event snapshot',
  })
  @ApiOkResponse({ type: EventSnapshotDto })
  async show(
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @CurrentEventAccess() access: EventAccess,
  ): Promise<EventSnapshotDto> {
    return EventSnapshotDto.fromDomain(
      await this.events.getSnapshot(eventId, access.memberId),
    );
  }

  @Post('host-transfer')
  @HttpCode(200)
  @RequireEventRole('HOST')
  @ApiOperation({
    operationId: 'createHostTransfer',
    summary: 'Create a short-lived one-time host transfer',
  })
  @ApiOkResponse({ type: CreateHostTransferResponseDto })
  async createTransfer(
    @Param('eventId', ParseUUIDPipe) eventId: string,
  ): Promise<CreateHostTransferResponseDto> {
    return CreateHostTransferResponseDto.fromDomain(
      await this.events.createHostTransfer(eventId),
    );
  }
}

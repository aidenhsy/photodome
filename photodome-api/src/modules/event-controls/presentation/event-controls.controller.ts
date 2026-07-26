import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Patch,
  Param,
  ParseUUIDPipe,
  Post,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { EventAccess } from '../../capabilities/domain/capability';
import { CurrentEventAccess } from '../../capabilities/presentation/current-event-access.decorator';
import { EventCapabilityGuard } from '../../capabilities/presentation/event-capability.guard';
import { RequireEventRole } from '../../capabilities/presentation/require-event-role.decorator';
import { EventControlsApplicationService } from '../application/event-controls-application.service';
import { RotatedJoinCodeDto } from '../../events/presentation/dto/event-access.dto';
import { EventSnapshotDto } from '../../events/presentation/dto/event.dto';
import { EventDomainExceptionFilter } from '../../events/presentation/event-domain-exception.filter';
import { EventMemberDto } from './dto/event-member.dto';
import { UpdateDisplayNameDto } from './dto/update-display-name.dto';

@ApiTags('event controls')
@ApiBearerAuth('eventCapability')
@Controller('events/:eventId')
@UseGuards(EventCapabilityGuard)
@UseFilters(EventDomainExceptionFilter)
export class EventControlsController {
  constructor(private readonly controls: EventControlsApplicationService) {}

  @Post('end')
  @RequireEventRole('HOST')
  @HttpCode(200)
  @ApiOperation({
    operationId: 'endEvent',
    summary: 'End an event and start its seven-day retention clock',
  })
  @ApiOkResponse({ type: EventSnapshotDto })
  async end(
    @Param('eventId', ParseUUIDPipe) _eventId: string,
    @CurrentEventAccess() access: EventAccess,
  ): Promise<EventSnapshotDto> {
    return EventSnapshotDto.fromDomain(await this.controls.endEvent(access));
  }

  @Post('restrict-uploads')
  @RequireEventRole('HOST')
  @HttpCode(200)
  @ApiOperation({
    operationId: 'restrictEventUploads',
    summary: 'Block new upload reservations after an event has ended',
  })
  @ApiOkResponse({ type: EventSnapshotDto })
  async restrict(
    @Param('eventId', ParseUUIDPipe) _eventId: string,
    @CurrentEventAccess() access: EventAccess,
  ): Promise<EventSnapshotDto> {
    return EventSnapshotDto.fromDomain(
      await this.controls.restrictUploads(access),
    );
  }

  @Get('members')
  @RequireEventRole('HOST')
  @ApiOperation({
    operationId: 'listEventMembers',
    summary: 'List active anonymous event members',
  })
  @ApiOkResponse({ type: EventMemberDto, isArray: true })
  async members(
    @Param('eventId', ParseUUIDPipe) _eventId: string,
    @CurrentEventAccess() access: EventAccess,
  ): Promise<EventMemberDto[]> {
    return (await this.controls.listMembers(access)).map((member) =>
      EventMemberDto.fromDomain(member),
    );
  }

  @Patch('members/me')
  @ApiOperation({
    operationId: 'updateOwnEventDisplayName',
    summary: 'Update the current member display name',
  })
  @ApiOkResponse({ type: EventSnapshotDto })
  async updateDisplayName(
    @Param('eventId', ParseUUIDPipe) _eventId: string,
    @CurrentEventAccess() access: EventAccess,
    @Body() input: UpdateDisplayNameDto,
  ): Promise<EventSnapshotDto> {
    return EventSnapshotDto.fromDomain(
      await this.controls.updateDisplayName(access, input.displayName),
    );
  }

  @Delete('members/:memberId')
  @RequireEventRole('HOST')
  @HttpCode(204)
  @ApiOperation({
    operationId: 'removeEventMember',
    summary: 'Remove an attendee and revoke their event access',
  })
  @ApiNoContentResponse()
  async removeMember(
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
  ): Promise<void> {
    await this.controls.removeMember(eventId, memberId);
  }

  @Post('rotate-code')
  @RequireEventRole('HOST')
  @HttpCode(200)
  @ApiOperation({
    operationId: 'rotateEventJoinCode',
    summary: 'Rotate the public join code',
  })
  @ApiOkResponse({ type: RotatedJoinCodeDto })
  async rotateCode(
    @Param('eventId', ParseUUIDPipe) _eventId: string,
    @CurrentEventAccess() access: EventAccess,
  ): Promise<RotatedJoinCodeDto> {
    return { joinCode: await this.controls.rotateJoinCode(access) };
  }
}

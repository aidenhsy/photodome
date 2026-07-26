import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { EventAccess } from '../../capabilities/domain/capability';
import { CurrentEventAccess } from '../../capabilities/presentation/current-event-access.decorator';
import { EventCapabilityGuard } from '../../capabilities/presentation/event-capability.guard';
import { LiveActivityApplicationService } from '../application/live-activity-application.service';
import { RegisterLiveActivityTokenDto } from './dto/register-live-activity-token.dto';

@ApiTags('live-activities')
@ApiBearerAuth('eventCapability')
@Controller('events/:eventId/live-activity-token')
@UseGuards(EventCapabilityGuard)
export class LiveActivitiesController {
  constructor(
    private readonly liveActivities: LiveActivityApplicationService,
  ) {}

  @Post()
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    operationId: 'registerEventLiveActivityToken',
    summary: 'Register the caller’s rotating ActivityKit push token',
    description:
      'Stores the current per-activity token for event photo-count updates. Calling again replaces the previous token for this event member.',
  })
  @ApiNoContentResponse()
  async register(
    @Param('eventId', ParseUUIDPipe) _eventId: string,
    @CurrentEventAccess() access: EventAccess,
    @Body() input: RegisterLiveActivityTokenDto,
  ): Promise<void> {
    await this.liveActivities.register(access, input.pushToken);
  }
}

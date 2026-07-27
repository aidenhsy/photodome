import {
  BadRequestException,
  Body,
  Controller,
  Headers,
  HttpCode,
  Post,
  UseFilters,
} from '@nestjs/common';
import {
  ApiCreatedResponse,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { EventApplicationService } from '../application/event-application.service';
import { CreateEventDto } from './dto/create-event.dto';
import { EventAccessDto, HostEventAccessDto } from './dto/event-access.dto';
import { JoinEventDto } from './dto/join-event.dto';
import { EventDomainExceptionFilter } from './event-domain-exception.filter';

@ApiTags('events')
@Controller('events')
@UseFilters(EventDomainExceptionFilter)
export class EventsPublicController {
  constructor(private readonly events: EventApplicationService) {}

  @Post()
  @Throttle({
    ip: { limit: 20, ttl: 60_000 },
    installation: { limit: 20, ttl: 60_000 },
    event: { limit: 20, ttl: 60_000 },
  })
  @ApiOperation({
    operationId: 'createEvent',
    summary: 'Create an event without an account',
  })
  @ApiCreatedResponse({ type: HostEventAccessDto })
  async create(@Body() input: CreateEventDto): Promise<HostEventAccessDto> {
    return HostEventAccessDto.fromDomain(await this.events.createEvent(input));
  }

  @Post('join')
  @HttpCode(200)
  @Throttle({
    ip: { limit: 12, ttl: 60_000 },
    installation: { limit: 12, ttl: 60_000 },
    event: { limit: 120, ttl: 60_000 },
  })
  @ApiOperation({
    operationId: 'joinEvent',
    summary: 'Join a private event with its short code',
  })
  @ApiOkResponse({ type: EventAccessDto })
  @ApiNotFoundResponse({
    description: 'Invite invalid, rotated, expired, or unavailable.',
  })
  async join(
    @Body() input: JoinEventDto,
    @Headers('x-photodome-installation-id')
    installationIdentity: string | undefined,
  ): Promise<EventAccessDto> {
    const normalizedIdentity = installationIdentity?.trim();
    if (!normalizedIdentity || normalizedIdentity.length > 128) {
      throw new BadRequestException(
        'A valid installation identity is required.',
      );
    }
    return EventAccessDto.fromDomain(
      await this.events.joinEvent({
        ...input,
        installationIdentity: normalizedIdentity,
      }),
    );
  }
}

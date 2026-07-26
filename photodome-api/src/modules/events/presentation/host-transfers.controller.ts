import { Body, Controller, HttpCode, Post, UseFilters } from '@nestjs/common';
import {
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { EventApplicationService } from '../application/event-application.service';
import { EventAccessDto } from './dto/event-access.dto';
import { ExchangeHostTransferDto } from './dto/host-transfer.dto';
import { EventDomainExceptionFilter } from './event-domain-exception.filter';

@ApiTags('host transfers')
@Controller('host-transfers')
@UseFilters(EventDomainExceptionFilter)
export class HostTransfersController {
  constructor(private readonly events: EventApplicationService) {}

  @Post('exchange')
  @HttpCode(200)
  @Throttle({ default: { limit: 12, ttl: 60_000 } })
  @ApiOperation({
    operationId: 'exchangeHostTransfer',
    summary: 'Exchange a one-time token for rotated host authority',
  })
  @ApiOkResponse({ type: EventAccessDto })
  @ApiNotFoundResponse({
    description: 'Transfer token invalid, consumed, or expired.',
  })
  async exchange(
    @Body() input: ExchangeHostTransferDto,
  ): Promise<EventAccessDto> {
    return EventAccessDto.fromDomain(
      await this.events.exchangeHostTransfer(input.transferToken),
    );
  }
}

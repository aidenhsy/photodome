import { Controller, Get } from '@nestjs/common';
import {
  ApiOkResponse,
  ApiOperation,
  ApiServiceUnavailableResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CheckReadinessUseCase } from '../application/check-readiness.use-case';
import { GetHealthUseCase } from '../application/get-health.use-case';
import { HealthResponseDto, ReadinessResponseDto } from './health-response.dto';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(
    private readonly getHealth: GetHealthUseCase,
    private readonly checkReadiness: CheckReadinessUseCase,
  ) {}

  @Get()
  @ApiOperation({
    operationId: 'getHealth',
    summary: 'Check API liveness',
  })
  @ApiOkResponse({ type: HealthResponseDto })
  show(): HealthResponseDto {
    return this.getHealth.execute();
  }

  @Get('ready')
  @ApiOperation({
    operationId: 'getReadiness',
    summary: 'Check PostgreSQL and Redis readiness',
  })
  @ApiOkResponse({ type: ReadinessResponseDto })
  @ApiServiceUnavailableResponse({ type: ReadinessResponseDto })
  ready(): Promise<ReadinessResponseDto> {
    return this.checkReadiness.execute();
  }
}

import {
  Controller,
  Get,
  Headers,
  NotFoundException,
  Res,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SkipThrottle } from '@nestjs/throttler';
import { ApiExcludeController } from '@nestjs/swagger';
import { createHash, timingSafeEqual } from 'node:crypto';
import type { Response } from 'express';
import type { Environment } from '../../../common/config/env.validation';
import { ExpiryMetricsService } from '../application/expiry-metrics.service';

@Controller('internal/metrics')
@ApiExcludeController()
export class MetricsController {
  constructor(
    private readonly metrics: ExpiryMetricsService,
    private readonly config: ConfigService<Environment, true>,
  ) {}

  @Get()
  @SkipThrottle()
  async getMetrics(
    @Headers('authorization') authorization: string | undefined,
    @Res() response: Response,
  ): Promise<void> {
    const expected = this.config.get('METRICS_BEARER_TOKEN', { infer: true });
    if (!expected) {
      throw new NotFoundException();
    }
    const provided = authorization?.startsWith('Bearer ')
      ? authorization.slice(7)
      : '';
    if (!this.matches(provided, expected)) {
      throw new UnauthorizedException();
    }
    const rendered = await this.metrics.render();
    response.type(rendered.contentType).send(rendered.body);
  }

  private matches(left: string, right: string): boolean {
    const leftDigest = createHash('sha256').update(left).digest();
    const rightDigest = createHash('sha256').update(right).digest();
    return timingSafeEqual(leftDigest, rightDigest);
  }
}

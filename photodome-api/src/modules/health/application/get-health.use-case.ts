import { Injectable } from '@nestjs/common';
import type { HealthStatus } from '../domain/health-status';

@Injectable()
export class GetHealthUseCase {
  execute(now: Date = new Date()): HealthStatus {
    return {
      status: 'ok',
      service: 'photodome-api',
      version: '0.1.0',
      timestamp: now.toISOString(),
    };
  }
}

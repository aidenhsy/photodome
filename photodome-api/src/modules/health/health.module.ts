import { Module } from '@nestjs/common';
import { CheckReadinessUseCase } from './application/check-readiness.use-case';
import { GetHealthUseCase } from './application/get-health.use-case';
import { HealthController } from './presentation/health.controller';

@Module({
  controllers: [HealthController],
  providers: [GetHealthUseCase, CheckReadinessUseCase],
})
export class HealthModule {}

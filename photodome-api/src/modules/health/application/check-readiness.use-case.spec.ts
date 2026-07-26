import { ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { PrismaService } from '../../../common/prisma/prisma.service';
import { CheckReadinessUseCase } from './check-readiness.use-case';

describe('CheckReadinessUseCase', () => {
  const config = new ConfigService({
    REDIS_URL: 'redis://127.0.0.1:6381',
  });

  it('reports unavailable when PostgreSQL cannot answer', async () => {
    const prisma = {
      $queryRaw: jest.fn().mockRejectedValue(new Error('database down')),
    } as unknown as PrismaService;
    const useCase = new CheckReadinessUseCase(prisma, config);

    await expect(
      useCase.execute(new Date('2026-07-25T00:00:00.000Z')),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    useCase.onApplicationShutdown();
  });
});

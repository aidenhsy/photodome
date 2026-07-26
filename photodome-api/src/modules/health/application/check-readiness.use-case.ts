import {
  Injectable,
  OnApplicationShutdown,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import type { Environment } from '../../../common/config/env.validation';
import { PrismaService } from '../../../common/prisma/prisma.service';

export interface ReadinessStatus {
  status: 'ready' | 'unavailable';
  service: 'photodome-api';
  timestamp: string;
  dependencies: {
    postgres: 'ok' | 'unavailable';
    redis: 'ok' | 'unavailable';
  };
}

@Injectable()
export class CheckReadinessUseCase implements OnApplicationShutdown {
  private readonly redis: Redis;

  constructor(
    private readonly prisma: PrismaService,
    config: ConfigService<Environment, true>,
  ) {
    this.redis = new Redis(config.get('REDIS_URL', { infer: true }), {
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      connectTimeout: 2_000,
    });
  }

  async execute(now: Date = new Date()): Promise<ReadinessStatus> {
    const [postgres, redis] = await Promise.allSettled([
      this.prisma.$queryRaw`SELECT 1`,
      this.redis.ping(),
    ]);
    const status: ReadinessStatus = {
      status:
        postgres.status === 'fulfilled' && redis.status === 'fulfilled'
          ? 'ready'
          : 'unavailable',
      service: 'photodome-api',
      timestamp: now.toISOString(),
      dependencies: {
        postgres: postgres.status === 'fulfilled' ? 'ok' : 'unavailable',
        redis: redis.status === 'fulfilled' ? 'ok' : 'unavailable',
      },
    };
    if (status.status === 'unavailable') {
      throw new ServiceUnavailableException(status);
    }
    return status;
  }

  onApplicationShutdown(): void {
    this.redis.disconnect();
  }
}

import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { LoggerModule } from 'nestjs-pino';
import type { Environment } from './common/config/env.validation';
import { validateEnvironment } from './common/config/env.validation';
import { PrismaModule } from './common/prisma/prisma.module';
import {
  eventTracker,
  installationTracker,
  ipTracker,
} from './common/security/throttle-trackers';
import { SENSITIVE_LOG_PATHS } from './common/logging/sensitive-log-redaction';
import { EventsModule } from './modules/events/events.module';
import { EventControlsModule } from './modules/event-controls/event-controls.module';
import { CurationModule } from './modules/curation/curation.module';
import { HealthModule } from './modules/health/health.module';
import { MediaModule } from './modules/media/media.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: validateEnvironment,
    }),
    ThrottlerModule.forRoot([
      {
        name: 'ip',
        ttl: 60_000,
        limit: 120,
        getTracker: (request) => ipTracker(request),
      },
      {
        name: 'installation',
        ttl: 60_000,
        limit: 120,
        getTracker: (request) => installationTracker(request),
      },
      {
        name: 'event',
        ttl: 60_000,
        limit: 120,
        getTracker: (request) => eventTracker(request),
      },
    ]),
    LoggerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService<Environment, true>) => ({
        pinoHttp: {
          level: config.get('LOG_LEVEL', { infer: true }),
          redact: {
            paths: [...SENSITIVE_LOG_PATHS],
            censor: '[REDACTED]',
          },
          transport:
            config.get('NODE_ENV', { infer: true }) === 'development'
              ? {
                  target: 'pino-pretty',
                  options: { colorize: true, singleLine: true },
                }
              : undefined,
        },
      }),
    }),
    PrismaModule,
    EventsModule,
    EventControlsModule,
    CurationModule,
    MediaModule,
    HealthModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}

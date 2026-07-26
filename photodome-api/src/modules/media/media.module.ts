import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { ConfigService } from '@nestjs/config';
import type { Environment } from '../../common/config/env.validation';
import { EventCapabilityGuard } from '../capabilities/presentation/event-capability.guard';
import { EventsModule } from '../events/events.module';
import { LiveActivitiesModule } from '../live-activities/live-activities.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { MediaApplicationService } from './application/media-application.service';
import {
  MEDIA_DELETION_QUEUE,
  MEDIA_PROCESSING_QUEUE,
} from './application/media.constants';
import { OBJECT_STORAGE_GATEWAY } from './application/ports/object-storage.gateway';
import { PHOTO_REPOSITORY } from './application/ports/photo.repository';
import { GCS_OBJECT_STORAGE_PROVIDER } from './infrastructure/gcs-object-storage.gateway';
import { GcsMediaBucketValidator } from './infrastructure/gcs-media-bucket.validator';
import { PhotoProcessingProcessor } from './infrastructure/photo-processing.processor';
import { PhotoDeletionProcessor } from './infrastructure/photo-deletion.processor';
import { PrismaPhotoRepository } from './infrastructure/prisma-photo.repository';
import { PhotosController } from './presentation/photos.controller';

const workerProviders =
  process.env.DISABLE_BACKGROUND_WORKERS === '1'
    ? []
    : [PhotoProcessingProcessor, PhotoDeletionProcessor];

@Module({
  imports: [
    EventsModule,
    LiveActivitiesModule,
    RealtimeModule,
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService<Environment, true>) => {
        const redis = new URL(config.get('REDIS_URL', { infer: true }));
        return {
          connection: {
            host: redis.hostname,
            port: Number(redis.port || '6379'),
            ...(redis.username
              ? { username: decodeURIComponent(redis.username) }
              : {}),
            ...(redis.password
              ? { password: decodeURIComponent(redis.password) }
              : {}),
            ...(redis.pathname.length > 1
              ? { db: Number(redis.pathname.slice(1)) }
              : {}),
            ...(redis.protocol === 'rediss:' ? { tls: {} } : {}),
          },
        };
      },
    }),
    BullModule.registerQueue(
      { name: MEDIA_PROCESSING_QUEUE },
      { name: MEDIA_DELETION_QUEUE },
    ),
  ],
  controllers: [PhotosController],
  providers: [
    MediaApplicationService,
    EventCapabilityGuard,
    GCS_OBJECT_STORAGE_PROVIDER,
    GcsMediaBucketValidator,
    {
      provide: PHOTO_REPOSITORY,
      useClass: PrismaPhotoRepository,
    },
    ...workerProviders,
  ],
  exports: [OBJECT_STORAGE_GATEWAY],
})
export class MediaModule {}

import { Inject } from '@nestjs/common';
import { Processor, WorkerHost } from '@nestjs/bullmq';
import type { Job } from 'bullmq';
import {
  OBJECT_STORAGE_GATEWAY,
  type ObjectStorageGateway,
} from '../application/ports/object-storage.gateway';
import {
  PHOTO_REPOSITORY,
  type PhotoRepository,
} from '../application/ports/photo.repository';
import { MEDIA_PROCESSING_QUEUE } from '../application/media.constants';
import {
  EVENT_REALTIME_PUBLISHER,
  type EventRealtimePublisher,
} from '../../realtime/realtime.constants';
import {
  EVENT_LIVE_ACTIVITY_PUBLISHER,
  type EventLiveActivityPublisher,
} from '../../live-activities/application/live-activity.constants';

interface ProcessPhotoJob {
  photoId: string;
}

@Processor(MEDIA_PROCESSING_QUEUE, { concurrency: 2 })
export class PhotoProcessingProcessor extends WorkerHost {
  constructor(
    @Inject(PHOTO_REPOSITORY)
    private readonly photos: PhotoRepository,
    @Inject(OBJECT_STORAGE_GATEWAY)
    private readonly storage: ObjectStorageGateway,
    @Inject(EVENT_REALTIME_PUBLISHER)
    private readonly realtime: EventRealtimePublisher,
    @Inject(EVENT_LIVE_ACTIVITY_PUBLISHER)
    private readonly liveActivities: EventLiveActivityPublisher,
  ) {
    super();
  }

  async process(job: Job<ProcessPhotoJob>): Promise<void> {
    const photo = await this.photos.findById(job.data.photoId);
    if (!photo || photo.state === 'READY') {
      return;
    }

    try {
      const metadata = await this.storage.processVariants(photo);
      const ready = await this.photos.markReady(photo.id, metadata, new Date());
      if (!ready) {
        await this.storage.deletePhotoObjects({
          photoId: photo.id,
          eventId: photo.eventId,
          originalKey: photo.originalKey,
          displayKey: photo.displayKey,
          thumbKey: photo.thumbKey,
        });
        return;
      }
      this.realtime.photoReady(ready.eventId, ready.id);
      this.liveActivities.photoReady(ready.eventId);
    } catch (error) {
      await this.photos.markFailed(
        photo.id,
        error instanceof Error ? error.message : 'Image processing failed',
      );
      throw error;
    }
  }
}

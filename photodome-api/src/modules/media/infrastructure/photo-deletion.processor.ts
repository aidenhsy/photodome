import { Inject } from '@nestjs/common';
import { Processor, WorkerHost } from '@nestjs/bullmq';
import type { Job } from 'bullmq';
import { MEDIA_DELETION_QUEUE } from '../application/media.constants';
import {
  OBJECT_STORAGE_GATEWAY,
  type ObjectStorageGateway,
} from '../application/ports/object-storage.gateway';
import {
  PHOTO_REPOSITORY,
  type PhotoRepository,
} from '../application/ports/photo.repository';

interface DeletePhotoJob {
  photoId: string;
}

@Processor(MEDIA_DELETION_QUEUE, { concurrency: 2 })
export class PhotoDeletionProcessor extends WorkerHost {
  constructor(
    @Inject(PHOTO_REPOSITORY)
    private readonly photos: PhotoRepository,
    @Inject(OBJECT_STORAGE_GATEWAY)
    private readonly storage: ObjectStorageGateway,
  ) {
    super();
  }

  async process(job: Job<DeletePhotoJob>): Promise<void> {
    const deletion = await this.photos.findDeletion(job.data.photoId);
    if (!deletion) {
      return;
    }

    try {
      await this.storage.deletePhotoObjects(deletion);
      if (await this.storage.photoObjectsExist(deletion)) {
        throw new Error('One or more photo objects still exist after deletion');
      }
      await this.photos.finalizeDeletion(deletion.photoId);
    } catch (error) {
      await this.photos.recordDeletionFailure(
        deletion.photoId,
        error instanceof Error ? error.message : 'Photo deletion failed',
        new Date(),
      );
      throw error;
    }
  }
}

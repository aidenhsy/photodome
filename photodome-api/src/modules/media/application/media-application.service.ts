import { Inject, Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import type { Queue } from 'bullmq';
import { randomUUID } from 'node:crypto';
import type { EventAccess } from '../../capabilities/domain/capability';
import {
  OBJECT_STORAGE_GATEWAY,
  type ObjectStorageGateway,
} from './ports/object-storage.gateway';
import {
  PHOTO_REPOSITORY,
  type PhotoRepository,
} from './ports/photo.repository';
import {
  InvalidPhotoReservationError,
  UploadedObjectMismatchError,
  UploadedObjectMissingError,
} from '../domain/media.errors';
import type { PhotoLifecycleState } from '../domain/photo';
import { MEDIA_PROCESSING_QUEUE } from './media.constants';
import { MEDIA_DELETION_QUEUE } from './media.constants';
import {
  EVENT_REALTIME_PUBLISHER,
  type EventRealtimePublisher,
} from '../../realtime/realtime.constants';

const MAX_ORIGINAL_BYTES = 20 * 1024 * 1024;
const MAX_DIMENSION = 20_000;

export interface PhotoReservationInput {
  contentType: string;
  byteSize: number;
  sha256: string;
  width: number;
  height: number;
  capturedAt?: string;
  orientation?: number;
}

export interface PhotoUploadGrant {
  photoId: string;
  uploadUrl: string;
  contentType: string;
  byteSize: number;
  state: PhotoLifecycleState;
}

export interface AlbumPhoto {
  id: string;
  contributorMemberId: string;
  width: number;
  height: number;
  capturedAt: Date | null;
  readyAt: Date;
  displayUrl: string;
  thumbnailUrl: string;
  urlsExpireAt: Date;
}

export interface AlbumPhotoPage {
  photos: AlbumPhoto[];
  nextCursor: string | null;
  readyPhotoCount: number;
}

@Injectable()
export class MediaApplicationService {
  constructor(
    @Inject(PHOTO_REPOSITORY)
    private readonly photos: PhotoRepository,
    @Inject(OBJECT_STORAGE_GATEWAY)
    private readonly storage: ObjectStorageGateway,
    @InjectQueue(MEDIA_PROCESSING_QUEUE)
    private readonly processingQueue: Queue,
    @InjectQueue(MEDIA_DELETION_QUEUE)
    private readonly deletionQueue: Queue,
    @Inject(EVENT_REALTIME_PUBLISHER)
    private readonly realtime: EventRealtimePublisher,
  ) {}

  async reserve(
    access: EventAccess,
    input: PhotoReservationInput,
    now: Date = new Date(),
  ): Promise<PhotoUploadGrant> {
    this.validateInput(input);
    const photoId = randomUUID();
    const prefix = `events/${access.eventId}/photos/${photoId}`;
    const photo = await this.photos.reserve({
      id: photoId,
      eventId: access.eventId,
      contributorMemberId: access.memberId,
      originalKey: `${prefix}/original.jpg`,
      displayKey: `${prefix}/display.jpg`,
      thumbKey: `${prefix}/thumb.jpg`,
      contentType: input.contentType,
      byteSize: input.byteSize,
      sha256: input.sha256.toLowerCase(),
      width: input.width,
      height: input.height,
      capturedAt: input.capturedAt ? new Date(input.capturedAt) : null,
      orientation: input.orientation ?? 1,
      now,
    });
    return this.createGrant(photo);
  }

  async renewUploadSession(
    eventId: string,
    photoId: string,
    memberId: string,
  ): Promise<PhotoUploadGrant> {
    const photo = await this.requireOwned(eventId, photoId, memberId);
    if (!['RESERVED', 'FAILED'].includes(photo.state)) {
      throw new InvalidPhotoReservationError();
    }
    return this.createGrant(photo);
  }

  async complete(
    eventId: string,
    photoId: string,
    memberId: string,
    now: Date = new Date(),
  ): Promise<PhotoLifecycleState> {
    const photo = await this.requireOwned(eventId, photoId, memberId);
    if (photo.state === 'READY' || photo.state === 'PROCESSING') {
      return photo.state;
    }

    const uploaded = await this.storage.inspectUploadedObject(photo);
    if (!uploaded) {
      throw new UploadedObjectMissingError();
    }
    if (
      uploaded.byteSize !== photo.byteSize ||
      uploaded.contentType !== photo.contentType ||
      uploaded.sha256 !== photo.sha256
    ) {
      throw new UploadedObjectMismatchError();
    }

    const processing = await this.photos.markProcessing(photo.id, now);
    await this.processingQueue.add(
      'process-photo',
      { photoId: processing.id },
      {
        jobId: `photo-${processing.id}`,
        attempts: 4,
        backoff: { type: 'exponential', delay: 1_000 },
        removeOnComplete: 100,
        removeOnFail: 100,
      },
    );
    return processing.state;
  }

  async list(
    eventId: string,
    cursor: string | null,
    limit: number,
  ): Promise<AlbumPhotoPage> {
    const page = await this.photos.listReady(eventId, cursor, limit);
    const photos = await Promise.all(
      page.photos.map(async (photo) => {
        const [display, thumbnail] = await Promise.all([
          this.storage.createReadUrl(photo.displayKey),
          this.storage.createReadUrl(photo.thumbKey),
        ]);
        return {
          id: photo.id,
          contributorMemberId: photo.contributorMemberId,
          width: photo.width,
          height: photo.height,
          capturedAt: photo.capturedAt,
          readyAt: photo.readyAt,
          displayUrl: display.url,
          thumbnailUrl: thumbnail.url,
          urlsExpireAt:
            display.expiresAt < thumbnail.expiresAt
              ? display.expiresAt
              : thumbnail.expiresAt,
        };
      }),
    );
    return {
      photos,
      nextCursor: page.nextCursor,
      readyPhotoCount: page.readyPhotoCount,
    };
  }

  async remove(
    eventId: string,
    photoId: string,
    memberId: string,
    now: Date = new Date(),
  ): Promise<void> {
    const deletion = await this.photos.markRemoved(
      eventId,
      photoId,
      memberId,
      now,
    );
    this.realtime.photoRemoved(eventId, photoId);
    await this.deletionQueue.add(
      'delete-photo',
      { photoId: deletion.photoId },
      {
        attempts: 8,
        backoff: { type: 'exponential', delay: 2_000 },
        removeOnComplete: 100,
        removeOnFail: 100,
      },
    );
  }

  private async createGrant(photo: {
    id: string;
    contentType: string;
    byteSize: number;
    state: PhotoLifecycleState;
  }): Promise<PhotoUploadGrant> {
    const fullPhoto = await this.photos.findById(photo.id);
    if (!fullPhoto) {
      throw new InvalidPhotoReservationError();
    }
    return {
      photoId: fullPhoto.id,
      uploadUrl: await this.storage.createUploadSession(fullPhoto),
      contentType: fullPhoto.contentType,
      byteSize: fullPhoto.byteSize,
      state: fullPhoto.state,
    };
  }

  private async requireOwned(
    eventId: string,
    photoId: string,
    memberId: string,
  ) {
    const photo = await this.photos.findOwned(eventId, photoId, memberId);
    if (!photo) {
      throw new InvalidPhotoReservationError();
    }
    return photo;
  }

  private validateInput(input: PhotoReservationInput): void {
    if (
      input.contentType !== 'image/jpeg' ||
      input.byteSize < 1 ||
      input.byteSize > MAX_ORIGINAL_BYTES ||
      input.width < 1 ||
      input.height < 1 ||
      input.width > MAX_DIMENSION ||
      input.height > MAX_DIMENSION ||
      !/^[a-fA-F0-9]{64}$/.test(input.sha256) ||
      (input.capturedAt && Number.isNaN(Date.parse(input.capturedAt))) ||
      (input.orientation !== undefined &&
        (input.orientation < 1 || input.orientation > 8))
    ) {
      throw new InvalidPhotoReservationError();
    }
  }
}

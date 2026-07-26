import { Inject, Injectable } from '@nestjs/common';
import type { EventAccess } from '../../capabilities/domain/capability';
import {
  OBJECT_STORAGE_GATEWAY,
  type ObjectStorageGateway,
} from '../../media/application/ports/object-storage.gateway';
import type {
  DownloadManifestMode,
  PhotoSelection,
  PhotoSelectionDecision,
} from '../domain/curation';
import {
  CURATION_REPOSITORY,
  type CurationRepository,
} from './ports/curation.repository';

export interface ReviewPhotoOutput {
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

export interface ReviewPageOutput {
  photos: ReviewPhotoOutput[];
  nextCursor: string | null;
  readyPhotoCount: number;
  decidedPhotoCount: number;
  keptPhotoCount: number;
}

export interface DownloadManifestPhotoOutput {
  id: string;
  contentType: string;
  byteSize: number;
  capturedAt: Date | null;
  readyAt: Date;
  originalUrl: string;
  urlExpiresAt: Date;
}

export interface DownloadManifestOutput {
  photos: DownloadManifestPhotoOutput[];
  nextCursor: string | null;
  totalPhotoCount: number;
}

@Injectable()
export class CurationApplicationService {
  constructor(
    @Inject(CURATION_REPOSITORY)
    private readonly curation: CurationRepository,
    @Inject(OBJECT_STORAGE_GATEWAY)
    private readonly storage: ObjectStorageGateway,
  ) {}

  setSelection(
    access: EventAccess,
    photoId: string,
    decision: PhotoSelectionDecision,
    now: Date = new Date(),
  ): Promise<PhotoSelection> {
    return this.curation.setSelection({
      eventId: access.eventId,
      memberId: access.memberId,
      photoId,
      decision,
      now,
    });
  }

  undoLatest(
    access: EventAccess,
    now: Date = new Date(),
  ): Promise<PhotoSelection | null> {
    return this.curation.undoLatest({
      eventId: access.eventId,
      memberId: access.memberId,
      now,
    });
  }

  async reviewPage(
    access: EventAccess,
    cursor: string | null,
    limit: number,
    now: Date = new Date(),
  ): Promise<ReviewPageOutput> {
    const page = await this.curation.reviewPage({
      eventId: access.eventId,
      memberId: access.memberId,
      cursor,
      limit,
      now,
    });
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
    return { ...page, photos };
  }

  async downloadManifest(
    access: EventAccess,
    mode: DownloadManifestMode,
    cursor: string | null,
    limit: number,
    photoId: string | null = null,
    now: Date = new Date(),
  ): Promise<DownloadManifestOutput> {
    const page = await this.curation.manifestPage({
      eventId: access.eventId,
      memberId: access.memberId,
      mode,
      cursor,
      limit,
      photoId,
      allowLive: photoId !== null || (access.role === 'HOST' && mode === 'ALL'),
      now,
    });
    const photos = await Promise.all(
      page.photos.map(async (photo) => {
        const original = await this.storage.createReadUrl(photo.originalKey);
        return {
          id: photo.id,
          contentType: photo.contentType,
          byteSize: photo.byteSize,
          capturedAt: photo.capturedAt,
          readyAt: photo.readyAt,
          originalUrl: original.url,
          urlExpiresAt: original.expiresAt,
        };
      }),
    );
    return { ...page, photos };
  }
}

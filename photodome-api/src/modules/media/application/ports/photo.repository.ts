import type {
  PhotoPage,
  PhotoDeletion,
  PhotoReservation,
  ProcessedPhotoMetadata,
} from '../../domain/photo';

export interface PhotoRepository {
  reserve(input: {
    id: string;
    eventId: string;
    contributorMemberId: string;
    originalKey: string;
    displayKey: string;
    thumbKey: string;
    contentType: string;
    byteSize: number;
    sha256: string;
    width: number;
    height: number;
    capturedAt: Date | null;
    orientation: number;
    now: Date;
  }): Promise<PhotoReservation>;
  findOwned(
    eventId: string,
    photoId: string,
    memberId: string,
  ): Promise<PhotoReservation | null>;
  markProcessing(photoId: string, uploadedAt: Date): Promise<PhotoReservation>;
  markReady(
    photoId: string,
    metadata: ProcessedPhotoMetadata,
    readyAt: Date,
  ): Promise<PhotoReservation | null>;
  markFailed(photoId: string, reason: string): Promise<void>;
  findById(photoId: string): Promise<PhotoReservation | null>;
  listReady(
    eventId: string,
    cursor: string | null,
    limit: number,
  ): Promise<PhotoPage>;
  markRemoved(
    eventId: string,
    photoId: string,
    memberId: string,
    removedAt: Date,
  ): Promise<PhotoDeletion>;
  findDeletion(photoId: string): Promise<PhotoDeletion | null>;
  recordDeletionFailure(
    photoId: string,
    error: string,
    attemptedAt: Date,
  ): Promise<void>;
  finalizeDeletion(photoId: string): Promise<void>;
}

export const PHOTO_REPOSITORY = Symbol('PHOTO_REPOSITORY');

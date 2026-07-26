import type {
  PhotoDeletion,
  PhotoReservation,
  ProcessedPhotoMetadata,
} from '../../domain/photo';

export interface UploadedObjectMetadata {
  byteSize: number;
  contentType: string;
  sha256: string;
}

export interface EventPrefixDeletionResult {
  objectsDeleted: number;
  bytesDeleted: number;
}

export interface ObjectStorageGateway {
  createUploadSession(photo: PhotoReservation): Promise<string>;
  inspectUploadedObject(
    photo: PhotoReservation,
  ): Promise<UploadedObjectMetadata | null>;
  processVariants(photo: PhotoReservation): Promise<ProcessedPhotoMetadata>;
  createReadUrl(objectKey: string): Promise<{
    url: string;
    expiresAt: Date;
  }>;
  deletePhotoObjects(photo: PhotoDeletion): Promise<void>;
  photoObjectsExist(photo: PhotoDeletion): Promise<boolean>;
  deleteEventPrefix(eventId: string): Promise<EventPrefixDeletionResult>;
  eventPrefixObjectsExist(eventId: string): Promise<boolean>;
  listStoredEventIds(): Promise<string[]>;
}

export const OBJECT_STORAGE_GATEWAY = Symbol('OBJECT_STORAGE_GATEWAY');

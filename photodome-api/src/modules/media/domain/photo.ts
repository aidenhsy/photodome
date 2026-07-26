export type PhotoLifecycleState =
  | 'RESERVED'
  | 'PROCESSING'
  | 'READY'
  | 'FAILED'
  | 'REMOVED'
  | 'EXPIRED';

export interface PhotoReservation {
  id: string;
  eventId: string;
  contributorMemberId: string;
  state: PhotoLifecycleState;
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
  reservedAt: Date;
  readyAt: Date | null;
}

export interface ReadyPhoto extends PhotoReservation {
  state: 'READY';
  readyAt: Date;
}

export interface PhotoPage {
  photos: ReadyPhoto[];
  nextCursor: string | null;
  readyPhotoCount: number;
}

export interface ProcessedPhotoMetadata {
  width: number;
  height: number;
}

export interface PhotoDeletion {
  photoId: string;
  eventId: string;
  originalKey: string;
  displayKey: string;
  thumbKey: string;
}

export type PhotoSelectionDecision = 'KEEP' | 'SKIP';
export type DownloadManifestMode = 'ALL' | 'KEPT';

export interface PhotoSelection {
  photoId: string;
  decision: PhotoSelectionDecision;
  decidedAt: Date;
}

export interface ReviewPhoto {
  id: string;
  contributorMemberId: string;
  displayKey: string;
  thumbKey: string;
  width: number;
  height: number;
  capturedAt: Date | null;
  readyAt: Date;
}

export interface ReviewPhotoPage {
  photos: ReviewPhoto[];
  nextCursor: string | null;
  readyPhotoCount: number;
  decidedPhotoCount: number;
  keptPhotoCount: number;
}

export interface ManifestPhoto {
  id: string;
  originalKey: string;
  contentType: string;
  byteSize: number;
  capturedAt: Date | null;
  readyAt: Date;
}

export interface ManifestPhotoPage {
  photos: ManifestPhoto[];
  nextCursor: string | null;
  totalPhotoCount: number;
}

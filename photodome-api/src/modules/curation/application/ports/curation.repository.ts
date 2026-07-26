import type {
  DownloadManifestMode,
  ManifestPhotoPage,
  PhotoSelection,
  PhotoSelectionDecision,
  ReviewPhotoPage,
} from '../../domain/curation';

export interface CurationRepository {
  setSelection(input: {
    eventId: string;
    memberId: string;
    photoId: string;
    decision: PhotoSelectionDecision;
    now: Date;
  }): Promise<PhotoSelection>;
  undoLatest(input: {
    eventId: string;
    memberId: string;
    now: Date;
  }): Promise<PhotoSelection | null>;
  reviewPage(input: {
    eventId: string;
    memberId: string;
    cursor: string | null;
    limit: number;
    now: Date;
  }): Promise<ReviewPhotoPage>;
  manifestPage(input: {
    eventId: string;
    memberId: string;
    mode: DownloadManifestMode;
    cursor: string | null;
    limit: number;
    photoId: string | null;
    allowLive: boolean;
    now: Date;
  }): Promise<ManifestPhotoPage>;
}

export const CURATION_REPOSITORY = Symbol('CURATION_REPOSITORY');

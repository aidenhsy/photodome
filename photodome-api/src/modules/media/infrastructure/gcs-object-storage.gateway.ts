import { Storage } from '@google-cloud/storage';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'node:crypto';
import sharp from 'sharp';
import type { Environment } from '../../../common/config/env.validation';
import {
  type EventPrefixDeletionResult,
  OBJECT_STORAGE_GATEWAY,
  type ObjectStorageGateway,
  type UploadedObjectMetadata,
} from '../application/ports/object-storage.gateway';
import type {
  PhotoDeletion,
  PhotoReservation,
  ProcessedPhotoMetadata,
} from '../domain/photo';

const MAX_INPUT_PIXELS = 80_000_000;
const EVENT_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DELETE_BATCH_SIZE = 20;

@Injectable()
export class GcsObjectStorageGateway implements ObjectStorageGateway {
  private readonly storage: Storage;
  private readonly bucketName: string;
  private readonly apiEndpoint: string;
  private readonly signedUrlTtlSeconds: number;

  constructor(config: ConfigService<Environment, true>) {
    const projectId = config.get('GCS_PROJECT_ID', { infer: true });
    this.bucketName = config.get('MEDIA_BUCKET_NAME', { infer: true });
    this.apiEndpoint = config.get('GCS_API_ENDPOINT', {
      infer: true,
    });
    this.signedUrlTtlSeconds = config.get('SIGNED_URL_TTL_SECONDS', {
      infer: true,
    });
    this.storage = new Storage({
      projectId,
      ...(this.apiEndpoint ? { apiEndpoint: this.apiEndpoint } : {}),
      ...(this.apiEndpoint ? { useAuthWithCustomEndpoint: false } : {}),
      retryOptions: {
        autoRetry: true,
        maxRetries: 3,
        totalTimeout: 10_000,
      },
    });
  }

  async createUploadSession(photo: PhotoReservation): Promise<string> {
    const [uploadUrl] = await this.storage
      .bucket(this.bucketName)
      .file(photo.originalKey)
      .createResumableUpload({
        metadata: {
          contentType: photo.contentType,
          cacheControl: 'private, no-store',
          metadata: {
            declaredSha256: photo.sha256,
            photoId: photo.id,
            eventId: photo.eventId,
          },
        },
      });
    return uploadUrl;
  }

  async inspectUploadedObject(
    photo: PhotoReservation,
  ): Promise<UploadedObjectMetadata | null> {
    const file = this.storage.bucket(this.bucketName).file(photo.originalKey);
    const [exists] = await file.exists();
    if (!exists) {
      return null;
    }
    const [metadata] = await file.getMetadata();
    const hash = createHash('sha256');
    for await (const chunk of file.createReadStream()) {
      hash.update(chunk as Buffer);
    }

    return {
      byteSize: Number(metadata.size),
      contentType: metadata.contentType ?? '',
      sha256: hash.digest('hex'),
    };
  }

  async processVariants(
    photo: PhotoReservation,
  ): Promise<ProcessedPhotoMetadata> {
    const bucket = this.storage.bucket(this.bucketName);
    const [uploaded] = await bucket.file(photo.originalKey).download();
    const inputMetadata = await sharp(uploaded, {
      limitInputPixels: MAX_INPUT_PIXELS,
    }).metadata();
    const display = await sharp(uploaded, {
      limitInputPixels: MAX_INPUT_PIXELS,
    })
      .rotate()
      .resize({
        width: 2_048,
        height: 2_048,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .jpeg({ quality: 82, mozjpeg: true })
      .toBuffer();
    const thumb = await sharp(uploaded, {
      limitInputPixels: MAX_INPUT_PIXELS,
    })
      .rotate()
      .resize({
        width: 512,
        height: 512,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .jpeg({ quality: 75, mozjpeg: true })
      .toBuffer();

    await Promise.all([
      this.saveJpeg(photo.displayKey, display),
      this.saveJpeg(photo.thumbKey, thumb),
    ]);

    const orientation = inputMetadata.orientation ?? photo.orientation;
    const swapsAxes = orientation >= 5 && orientation <= 8;
    return {
      width: swapsAxes ? inputMetadata.height : inputMetadata.width,
      height: swapsAxes ? inputMetadata.width : inputMetadata.height,
    };
  }

  async createReadUrl(objectKey: string): Promise<{
    url: string;
    expiresAt: Date;
  }> {
    const expiresAt = new Date(Date.now() + this.signedUrlTtlSeconds * 1_000);
    if (this.apiEndpoint) {
      const base = this.apiEndpoint.replace(/\/$/, '');
      return {
        url: `${base}/download/storage/v1/b/${encodeURIComponent(
          this.bucketName,
        )}/o/${encodeURIComponent(objectKey)}?alt=media`,
        expiresAt,
      };
    }

    const [url] = await this.storage
      .bucket(this.bucketName)
      .file(objectKey)
      .getSignedUrl({
        version: 'v4',
        action: 'read',
        expires: expiresAt,
      });
    return { url, expiresAt };
  }

  async deletePhotoObjects(photo: PhotoDeletion): Promise<void> {
    const bucket = this.storage.bucket(this.bucketName);
    await Promise.all(
      [photo.originalKey, photo.displayKey, photo.thumbKey].map((key) =>
        bucket.file(key).delete({ ignoreNotFound: true }),
      ),
    );
  }

  async photoObjectsExist(photo: PhotoDeletion): Promise<boolean> {
    const bucket = this.storage.bucket(this.bucketName);
    const results = await Promise.all(
      [photo.originalKey, photo.displayKey, photo.thumbKey].map((key) =>
        bucket.file(key).exists(),
      ),
    );
    return results.some(([exists]) => exists);
  }

  async deleteEventPrefix(eventId: string): Promise<EventPrefixDeletionResult> {
    const prefix = this.eventPrefix(eventId);
    const bucket = this.storage.bucket(this.bucketName);
    const [files] = await bucket.getFiles({ prefix, versions: true });
    let bytesDeleted = 0;
    for (let offset = 0; offset < files.length; offset += DELETE_BATCH_SIZE) {
      const batch = files.slice(offset, offset + DELETE_BATCH_SIZE);
      await Promise.all(
        batch.map(async (file) => {
          bytesDeleted += Number(file.metadata.size ?? 0);
          await file.delete({ ignoreNotFound: true });
        }),
      );
    }
    return { objectsDeleted: files.length, bytesDeleted };
  }

  async eventPrefixObjectsExist(eventId: string): Promise<boolean> {
    const [files] = await this.storage.bucket(this.bucketName).getFiles({
      prefix: this.eventPrefix(eventId),
      versions: true,
      maxResults: 1,
    });
    return files.length > 0;
  }

  async listStoredEventIds(): Promise<string[]> {
    const [files] = await this.storage.bucket(this.bucketName).getFiles({
      prefix: 'events/',
      versions: true,
    });
    const ids = new Set<string>();
    for (const file of files) {
      const eventId = file.name.split('/')[1];
      if (eventId && EVENT_ID_PATTERN.test(eventId)) {
        ids.add(eventId);
      }
    }
    return [...ids];
  }

  private async saveJpeg(objectKey: string, bytes: Buffer): Promise<void> {
    await this.storage
      .bucket(this.bucketName)
      .file(objectKey)
      .save(bytes, {
        resumable: false,
        contentType: 'image/jpeg',
        metadata: {
          cacheControl: 'private, no-store',
        },
      });
  }

  private eventPrefix(eventId: string): string {
    if (!EVENT_ID_PATTERN.test(eventId)) {
      throw new Error('Event ID is not safe for prefix cleanup');
    }
    return `events/${eventId}/`;
  }
}

export const GCS_OBJECT_STORAGE_PROVIDER = {
  provide: OBJECT_STORAGE_GATEWAY,
  useClass: GcsObjectStorageGateway,
};

import { Storage } from '@google-cloud/storage';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { createHash, randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { AppModule } from '../src/app.module';
import type { Environment } from '../src/common/config/env.validation';
import {
  OBJECT_STORAGE_GATEWAY,
  type ObjectStorageGateway,
} from '../src/modules/media/application/ports/object-storage.gateway';
import type { PhotoReservation } from '../src/modules/media/domain/photo';

// This targets real Google Cloud Storage, whether the configured bucket is a
// development or production environment.
async function verify(): Promise<void> {
  const context = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn'],
  });
  const config = context.get(ConfigService<Environment, true>);
  const projectId = config.get('GCS_PROJECT_ID', { infer: true });
  const bucketName = config.get('MEDIA_BUCKET_NAME', { infer: true });
  const apiEndpoint = config.get('GCS_API_ENDPOINT', { infer: true });
  if (apiEndpoint) {
    await context.close();
    throw new Error(
      'GCS_API_ENDPOINT must be empty for production GCS verification.',
    );
  }

  const storage = new Storage({ projectId });
  const bucket = storage.bucket(bucketName);
  const eventId = randomUUID();
  const photoId = randomUUID();
  const eventPrefix = `events/${eventId}/`;
  const prefix = `events/${eventId}/photos/${photoId}`;
  const keys = [
    `${prefix}/original.jpg`,
    `${prefix}/display.jpg`,
    `${prefix}/thumb.jpg`,
  ];
  const abandonedKey = `${eventPrefix}abandoned/upload.tmp`;
  const gateway = context.get<ObjectStorageGateway>(OBJECT_STORAGE_GATEWAY);

  try {
    const source = await sharp({
      create: {
        width: 1_200,
        height: 800,
        channels: 3,
        background: { r: 18, g: 18, b: 18 },
      },
    })
      .jpeg({ quality: 92 })
      .toBuffer();
    const photo: PhotoReservation = {
      id: photoId,
      eventId,
      contributorMemberId: randomUUID(),
      state: 'RESERVED',
      originalKey: keys[0]!,
      displayKey: keys[1]!,
      thumbKey: keys[2]!,
      contentType: 'image/jpeg',
      byteSize: source.byteLength,
      sha256: createHash('sha256').update(source).digest('hex'),
      width: 1_200,
      height: 800,
      capturedAt: new Date(),
      orientation: 1,
      reservedAt: new Date(),
      readyAt: null,
    };

    const uploadUrl = await gateway.createUploadSession(photo);
    const upload = await fetch(uploadUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': photo.contentType,
        'Content-Length': String(source.byteLength),
        'Content-Range': `bytes 0-${source.byteLength - 1}/${source.byteLength}`,
      },
      body: source,
    });
    assert(upload.ok, `resumable upload returned HTTP ${upload.status}`);

    const inspected = await gateway.inspectUploadedObject(photo);
    assert(inspected !== null, 'uploaded original was not found');
    assert(
      inspected.byteSize === photo.byteSize,
      'uploaded byte count did not match',
    );
    assert(inspected.sha256 === photo.sha256, 'uploaded SHA-256 did not match');

    const processed = await gateway.processVariants(photo);
    assert(
      processed.width === 1_200 && processed.height === 800,
      'processed dimensions did not match',
    );

    for (const key of keys) {
      const file = bucket.file(key);
      const [metadata] = await file.getMetadata();
      assert(metadata.contentType === 'image/jpeg', `${key} is not JPEG`);
      assert(
        metadata.cacheControl === 'private, no-store',
        `${key} does not use private, no-store`,
      );

      const rawPath = key
        .split('/')
        .map((segment) => encodeURIComponent(segment))
        .join('/');
      const anonymous = await fetch(
        `https://storage.googleapis.com/${encodeURIComponent(bucketName)}/${rawPath}`,
      );
      assert(!anonymous.ok, `${key} was readable without a signed URL`);

      const signed = await gateway.createReadUrl(key);
      const privateRead = await fetch(signed.url);
      assert(
        privateRead.ok,
        `${key} signed read returned HTTP ${privateRead.status}`,
      );
      assert(
        privateRead.headers.get('content-type')?.startsWith('image/jpeg') ??
          false,
        `${key} signed read did not return image/jpeg`,
      );
    }

    await bucket.file(abandonedKey).save(Buffer.from('abandoned upload'), {
      resumable: false,
      contentType: 'application/octet-stream',
    });
    const [created] = await bucket.getFiles({
      prefix: eventPrefix,
      versions: true,
    });
    assert(
      created.length === 4,
      'expected three media objects and one abandoned object',
    );
    process.stdout.write(
      `Verified private GCS media lifecycle in gs://${bucketName}/${eventPrefix}\n`,
    );
  } finally {
    const deleted = await gateway.deleteEventPrefix(eventId);
    const [remaining] = await bucket.getFiles({
      prefix: eventPrefix,
      versions: true,
    });
    await context.close();
    assert(
      remaining.length === 0,
      `verification cleanup left ${remaining.length} object generation(s)`,
    );
    assert(
      deleted.objectsDeleted >= 0,
      'cleanup did not return an object count',
    );
    process.stdout.write(
      `Verified cleanup removed ${deleted.objectsDeleted} object generation(s) and left zero.\n`,
    );
  }
}

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

void verify().catch((error: unknown) => {
  process.stderr.write(
    `${error instanceof Error ? error.message : String(error)}\n`,
  );
  process.exitCode = 1;
});

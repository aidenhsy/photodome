import { Injectable } from '@nestjs/common';
import { EventState, PhotoState, Prisma, type Photo } from '@prisma/client';
import { PrismaService } from '../../../common/prisma/prisma.service';
import type { PhotoRepository } from '../application/ports/photo.repository';
import {
  InvalidPhotoReservationError,
  PhotoCapacityError,
  UploadAdmissionClosedError,
} from '../domain/media.errors';
import type {
  PhotoPage,
  PhotoDeletion,
  PhotoReservation,
  ProcessedPhotoMetadata,
  ReadyPhoto,
} from '../domain/photo';

const MAX_EVENT_PHOTOS = 2_000;
const SERIALIZABLE_RETRY_ATTEMPTS = 3;

@Injectable()
export class PrismaPhotoRepository implements PhotoRepository {
  constructor(private readonly prisma: PrismaService) {}

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
  }): Promise<PhotoReservation> {
    return this.serializable(async (transaction) => {
      const [event, member, photoCount] = await Promise.all([
        transaction.event.findUnique({ where: { id: input.eventId } }),
        transaction.eventMember.findFirst({
          where: {
            id: input.contributorMemberId,
            eventId: input.eventId,
            removedAt: null,
          },
        }),
        transaction.photo.count({
          where: {
            eventId: input.eventId,
            state: { notIn: [PhotoState.REMOVED, PhotoState.EXPIRED] },
          },
        }),
      ]);

      if (
        !event ||
        !member ||
        event.state === EventState.EXPIRING ||
        (event.expiresAt && event.expiresAt <= input.now)
      ) {
        throw new InvalidPhotoReservationError();
      }
      if (event.uploadsRestrictedAt) {
        throw new UploadAdmissionClosedError();
      }
      if (photoCount >= MAX_EVENT_PHOTOS) {
        throw new PhotoCapacityError();
      }

      return this.map(
        await transaction.photo.create({
          data: {
            id: input.id,
            eventId: input.eventId,
            contributorMemberId: input.contributorMemberId,
            originalKey: input.originalKey,
            displayKey: input.displayKey,
            thumbKey: input.thumbKey,
            contentType: input.contentType,
            byteSize: input.byteSize,
            sha256: input.sha256,
            width: input.width,
            height: input.height,
            capturedAt: input.capturedAt,
            orientation: input.orientation,
            admittedBeforeRestriction: true,
            reservedAt: input.now,
          },
        }),
      );
    });
  }

  async findOwned(
    eventId: string,
    photoId: string,
    memberId: string,
  ): Promise<PhotoReservation | null> {
    const photo = await this.prisma.photo.findFirst({
      where: {
        id: photoId,
        eventId,
        contributorMemberId: memberId,
        event: {
          state: { not: EventState.EXPIRING },
          OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
        },
      },
    });
    return photo ? this.map(photo) : null;
  }

  async markProcessing(
    photoId: string,
    uploadedAt: Date,
  ): Promise<PhotoReservation> {
    const current = await this.prisma.photo.findUnique({
      where: { id: photoId },
    });
    if (!current) {
      throw new InvalidPhotoReservationError();
    }
    if (
      current.state === PhotoState.PROCESSING ||
      current.state === PhotoState.READY
    ) {
      return this.map(current);
    }
    if (
      current.state === PhotoState.REMOVED ||
      current.state === PhotoState.EXPIRED
    ) {
      throw new InvalidPhotoReservationError();
    }

    return this.map(
      await this.prisma.photo.update({
        where: { id: photoId },
        data: {
          state: PhotoState.PROCESSING,
          uploadedAt,
          failureReason: null,
        },
      }),
    );
  }

  async markReady(
    photoId: string,
    metadata: ProcessedPhotoMetadata,
    readyAt: Date,
  ): Promise<PhotoReservation | null> {
    return this.prisma.$transaction(async (transaction) => {
      const photo = await transaction.photo.findUnique({
        where: { id: photoId },
        include: {
          event: {
            select: { state: true, expiresAt: true },
          },
        },
      });
      if (!photo) {
        return null;
      }
      if (
        photo.event.state === EventState.EXPIRING ||
        (photo.event.expiresAt && photo.event.expiresAt <= readyAt) ||
        photo.state === PhotoState.REMOVED ||
        photo.state === PhotoState.EXPIRED
      ) {
        await transaction.photo.updateMany({
          where: {
            id: photoId,
            state: { not: PhotoState.REMOVED },
          },
          data: { state: PhotoState.EXPIRED },
        });
        return null;
      }
      return this.map(
        await transaction.photo.update({
          where: { id: photoId },
          data: {
            state: PhotoState.READY,
            width: metadata.width,
            height: metadata.height,
            readyAt,
            failureReason: null,
          },
        }),
      );
    });
  }

  async markFailed(photoId: string, reason: string): Promise<void> {
    await this.prisma.photo.updateMany({
      where: {
        id: photoId,
        state: {
          notIn: [PhotoState.READY, PhotoState.REMOVED, PhotoState.EXPIRED],
        },
      },
      data: {
        state: PhotoState.FAILED,
        failureReason: reason.slice(0, 160),
      },
    });
  }

  async findById(photoId: string): Promise<PhotoReservation | null> {
    const photo = await this.prisma.photo.findUnique({
      where: { id: photoId },
    });
    return photo ? this.map(photo) : null;
  }

  async listReady(
    eventId: string,
    cursor: string | null,
    limit: number,
  ): Promise<PhotoPage> {
    const [rows, readyPhotoCount] = await this.prisma.$transaction([
      this.prisma.photo.findMany({
        where: { eventId, state: PhotoState.READY },
        orderBy: [{ readyAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
        ...(cursor
          ? {
              cursor: { id: cursor },
              skip: 1,
            }
          : {}),
      }),
      this.prisma.photo.count({
        where: { eventId, state: PhotoState.READY },
      }),
    ]);
    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;

    return {
      photos: pageRows.map((row) => this.mapReady(row)),
      nextCursor: hasMore ? (pageRows.at(-1)?.id ?? null) : null,
      readyPhotoCount,
    };
  }

  async markRemoved(
    eventId: string,
    photoId: string,
    memberId: string,
    removedAt: Date,
  ): Promise<PhotoDeletion> {
    return this.prisma.$transaction(async (transaction) => {
      const photo = await transaction.photo.findFirst({
        where: {
          id: photoId,
          eventId,
          contributorMemberId: memberId,
          state: { in: [PhotoState.READY, PhotoState.REMOVED] },
        },
      });
      if (!photo) {
        throw new InvalidPhotoReservationError();
      }

      if (photo.state === PhotoState.READY) {
        await transaction.photo.update({
          where: { id: photoId },
          data: { state: PhotoState.REMOVED, removedAt },
        });
      }
      const tombstone = await transaction.photoDeletionTombstone.upsert({
        where: { photoId },
        create: {
          photoId,
          eventId,
          originalKey: photo.originalKey,
          displayKey: photo.displayKey,
          thumbKey: photo.thumbKey,
        },
        update: {},
      });
      return {
        photoId: tombstone.photoId,
        eventId: tombstone.eventId,
        originalKey: tombstone.originalKey,
        displayKey: tombstone.displayKey,
        thumbKey: tombstone.thumbKey,
      };
    });
  }

  async findDeletion(photoId: string): Promise<PhotoDeletion | null> {
    const tombstone = await this.prisma.photoDeletionTombstone.findUnique({
      where: { photoId },
    });
    return tombstone
      ? {
          photoId: tombstone.photoId,
          eventId: tombstone.eventId,
          originalKey: tombstone.originalKey,
          displayKey: tombstone.displayKey,
          thumbKey: tombstone.thumbKey,
        }
      : null;
  }

  async recordDeletionFailure(
    photoId: string,
    error: string,
    attemptedAt: Date,
  ): Promise<void> {
    await this.prisma.photoDeletionTombstone.updateMany({
      where: { photoId },
      data: {
        attemptCount: { increment: 1 },
        lastAttemptAt: attemptedAt,
        lastError: error.slice(0, 500),
      },
    });
  }

  async finalizeDeletion(photoId: string): Promise<void> {
    await this.prisma.$transaction(async (transaction) => {
      const tombstone = await transaction.photoDeletionTombstone.findUnique({
        where: { photoId },
      });
      if (!tombstone) {
        return;
      }
      await transaction.photo.delete({ where: { id: photoId } });
    });
  }

  private map(photo: Photo): PhotoReservation {
    return {
      id: photo.id,
      eventId: photo.eventId,
      contributorMemberId: photo.contributorMemberId,
      state: photo.state,
      originalKey: photo.originalKey,
      displayKey: photo.displayKey,
      thumbKey: photo.thumbKey,
      contentType: photo.contentType,
      byteSize: photo.byteSize,
      sha256: photo.sha256,
      width: photo.width,
      height: photo.height,
      capturedAt: photo.capturedAt,
      orientation: photo.orientation,
      reservedAt: photo.reservedAt,
      readyAt: photo.readyAt,
    };
  }

  private mapReady(photo: Photo): ReadyPhoto {
    const mapped = this.map(photo);
    if (mapped.state !== 'READY' || !mapped.readyAt) {
      throw new Error('Ready-photo query returned a non-ready row');
    }
    return { ...mapped, state: 'READY', readyAt: mapped.readyAt };
  }

  private async serializable<T>(
    operation: (transaction: Prisma.TransactionClient) => Promise<T>,
  ): Promise<T> {
    for (let attempt = 0; attempt < SERIALIZABLE_RETRY_ATTEMPTS; attempt += 1) {
      try {
        return await this.prisma.$transaction(operation, {
          isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
        });
      } catch (error) {
        if (
          !(
            error instanceof Prisma.PrismaClientKnownRequestError &&
            error.code === 'P2034'
          ) ||
          attempt === SERIALIZABLE_RETRY_ATTEMPTS - 1
        ) {
          throw error;
        }
      }
    }
    throw new Error('Serializable photo reservation retry loop exhausted');
  }
}

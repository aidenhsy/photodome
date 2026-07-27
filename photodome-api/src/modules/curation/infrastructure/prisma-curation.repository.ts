import { Injectable } from '@nestjs/common';
import {
  EventState,
  PhotoSelectionDecision as PrismaPhotoSelectionDecision,
  PhotoState,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../common/prisma/prisma.service';
import type { CurationRepository } from '../application/ports/curation.repository';
import type {
  DownloadManifestMode,
  ManifestPhotoPage,
  PhotoSelection,
  PhotoSelectionDecision,
  ReviewPhotoPage,
} from '../domain/curation';
import {
  CurationUnavailableError,
  SelectionPhotoUnavailableError,
} from '../domain/curation.errors';

@Injectable()
export class PrismaCurationRepository implements CurationRepository {
  constructor(private readonly prisma: PrismaService) {}

  async setSelection(input: {
    eventId: string;
    memberId: string;
    photoId: string;
    decision: PhotoSelectionDecision;
    now: Date;
  }): Promise<PhotoSelection> {
    return this.prisma.$transaction(
      async (transaction) => {
        await this.requireAvailable(
          transaction,
          input.eventId,
          input.memberId,
          input.now,
        );
        const photo = await transaction.photo.findFirst({
          where: {
            id: input.photoId,
            eventId: input.eventId,
            state: PhotoState.READY,
            contributorMemberId: { not: input.memberId },
          },
          select: { id: true },
        });
        if (!photo) {
          throw new SelectionPhotoUnavailableError();
        }

        const selection = await transaction.photoSelection.upsert({
          where: {
            memberId_photoId: {
              memberId: input.memberId,
              photoId: input.photoId,
            },
          },
          create: {
            eventId: input.eventId,
            memberId: input.memberId,
            photoId: input.photoId,
            decision: input.decision,
            decidedAt: input.now,
          },
          update: {
            decision: input.decision,
            decidedAt: input.now,
          },
        });
        return this.mapSelection(selection);
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted },
    );
  }

  async undoLatest(input: {
    eventId: string;
    memberId: string;
    now: Date;
  }): Promise<PhotoSelection | null> {
    return this.prisma.$transaction(async (transaction) => {
      await this.requireAvailable(
        transaction,
        input.eventId,
        input.memberId,
        input.now,
      );
      const latest = await transaction.photoSelection.findFirst({
        where: {
          eventId: input.eventId,
          memberId: input.memberId,
          photo: {
            state: PhotoState.READY,
            contributorMemberId: { not: input.memberId },
          },
        },
        orderBy: [{ decidedAt: 'desc' }, { id: 'desc' }],
      });
      if (!latest) {
        return null;
      }
      await transaction.photoSelection.delete({ where: { id: latest.id } });
      return this.mapSelection(latest);
    });
  }

  async reviewPage(input: {
    eventId: string;
    memberId: string;
    cursor: string | null;
    limit: number;
    now: Date;
  }): Promise<ReviewPhotoPage> {
    await this.requireAvailable(
      this.prisma,
      input.eventId,
      input.memberId,
      input.now,
    );
    const selectionWhere = {
      eventId: input.eventId,
      memberId: input.memberId,
    };
    const eligiblePhotoWhere: Prisma.PhotoWhereInput = {
      eventId: input.eventId,
      state: PhotoState.READY,
      contributorMemberId: { not: input.memberId },
    };
    const [rows, readyPhotoCount, decidedPhotoCount, keptPhotoCount] =
      await this.prisma.$transaction([
        this.prisma.photo.findMany({
          where: {
            ...eligiblePhotoWhere,
            selections: { none: { memberId: input.memberId } },
          },
          orderBy: [{ readyAt: 'asc' }, { id: 'asc' }],
          take: input.limit + 1,
          ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
        }),
        this.prisma.photo.count({
          where: eligiblePhotoWhere,
        }),
        this.prisma.photoSelection.count({
          where: {
            ...selectionWhere,
            photo: {
              state: PhotoState.READY,
              contributorMemberId: { not: input.memberId },
            },
          },
        }),
        this.prisma.photoSelection.count({
          where: {
            ...selectionWhere,
            decision: PrismaPhotoSelectionDecision.KEEP,
            photo: {
              state: PhotoState.READY,
              contributorMemberId: { not: input.memberId },
            },
          },
        }),
      ]);
    const hasMore = rows.length > input.limit;
    const pageRows = hasMore ? rows.slice(0, input.limit) : rows;
    return {
      photos: pageRows.map((photo) => ({
        id: photo.id,
        contributorMemberId: photo.contributorMemberId,
        displayKey: photo.displayKey,
        thumbKey: photo.thumbKey,
        width: photo.width,
        height: photo.height,
        capturedAt: photo.capturedAt,
        readyAt: photo.readyAt!,
      })),
      nextCursor: hasMore ? (pageRows.at(-1)?.id ?? null) : null,
      readyPhotoCount,
      decidedPhotoCount,
      keptPhotoCount,
    };
  }

  async manifestPage(input: {
    eventId: string;
    memberId: string;
    mode: DownloadManifestMode;
    cursor: string | null;
    limit: number;
    photoId: string | null;
    allowLive: boolean;
    now: Date;
  }): Promise<ManifestPhotoPage> {
    await this.requireAvailable(
      this.prisma,
      input.eventId,
      input.memberId,
      input.now,
    );
    const where: Prisma.PhotoWhereInput = {
      eventId: input.eventId,
      state: PhotoState.READY,
      ...(input.photoId
        ? { id: input.photoId }
        : { contributorMemberId: { not: input.memberId } }),
      ...(input.mode === 'KEPT'
        ? {
            selections: {
              some: {
                memberId: input.memberId,
                decision: PrismaPhotoSelectionDecision.KEEP,
              },
            },
          }
        : {}),
    };
    const [rows, totalPhotoCount] = await this.prisma.$transaction([
      this.prisma.photo.findMany({
        where,
        orderBy: [{ readyAt: 'asc' }, { id: 'asc' }],
        take: input.limit + 1,
        ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
      }),
      this.prisma.photo.count({ where }),
    ]);
    const hasMore = rows.length > input.limit;
    const pageRows = hasMore ? rows.slice(0, input.limit) : rows;
    return {
      photos: pageRows.map((photo) => ({
        id: photo.id,
        originalKey: photo.originalKey,
        contentType: photo.contentType,
        byteSize: photo.byteSize,
        capturedAt: photo.capturedAt,
        readyAt: photo.readyAt!,
      })),
      nextCursor: hasMore ? (pageRows.at(-1)?.id ?? null) : null,
      totalPhotoCount,
    };
  }

  private async requireAvailable(
    transaction: Prisma.TransactionClient | PrismaService,
    eventId: string,
    memberId: string,
    now: Date,
  ): Promise<void> {
    const member = await transaction.eventMember.findFirst({
      where: {
        id: memberId,
        eventId,
        removedAt: null,
        event: {
          OR: [
            { state: EventState.LIVE },
            { state: EventState.ENDED, expiresAt: { gt: now } },
          ],
        },
      },
      select: { id: true },
    });
    if (!member) {
      throw new CurationUnavailableError();
    }
  }

  private mapSelection(selection: {
    photoId: string;
    decision: PrismaPhotoSelectionDecision;
    decidedAt: Date;
  }): PhotoSelection {
    return {
      photoId: selection.photoId,
      decision: selection.decision,
      decidedAt: selection.decidedAt,
    };
  }
}

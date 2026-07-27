import { Injectable } from '@nestjs/common';
import {
  EventMemberRole as PrismaEventMemberRole,
  EventState as PrismaEventState,
  Prisma,
} from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { PrismaService } from '../../../common/prisma/prisma.service';
import type {
  EventMemberCredential,
  EventMemberSummary,
  EventSnapshot,
  EventState,
} from '../domain/event';
import {
  EventCapacityError,
  EventNotEndedError,
  EventUnavailableError,
  InvalidModerationTargetError,
  InvalidHostTransferError,
  InvalidInviteError,
  JoinCodeConflictError,
} from '../domain/event.errors';
import type {
  CreatedEvent,
  EventRepository,
  JoinedEvent,
} from '../application/ports/event.repository';

const MAX_ACTIVE_EVENT_MEMBERS = 100;
const SERIALIZABLE_RETRY_ATTEMPTS = 3;
const EVENT_RETENTION_MS = 7 * 24 * 60 * 60 * 1_000;

interface EventRow {
  id: string;
  name: string;
  hostDisplayName: string;
  locationLabel: string | null;
  state: PrismaEventState;
  uploadsRestrictedAt: Date | null;
  endedAt: Date | null;
  expiresAt: Date | null;
  createdAt: Date;
}

@Injectable()
export class PrismaEventRepository implements EventRepository {
  constructor(private readonly prisma: PrismaService) {}

  async createEvent(input: {
    name: string;
    hostDisplayName: string;
    locationLabel: string | null;
    joinCodeHash: string;
    hostCapabilityHash: string;
  }): Promise<CreatedEvent> {
    try {
      const created = await this.prisma.event.create({
        data: {
          name: input.name,
          hostDisplayName: input.hostDisplayName,
          locationLabel: input.locationLabel,
          joinCodeHash: input.joinCodeHash,
          members: {
            create: {
              role: PrismaEventMemberRole.HOST,
              displayName: input.hostDisplayName,
              capabilityHash: input.hostCapabilityHash,
            },
          },
        },
        include: { members: true },
      });
      const host = created.members[0];
      if (!host) {
        throw new EventUnavailableError();
      }

      return {
        event: this.toSnapshot(created, 1, 0, {
          eventId: created.id,
          memberId: host.id,
          role: 'HOST',
        }),
      };
    } catch (error) {
      if (this.isUniqueConflict(error)) {
        throw new JoinCodeConflictError();
      }
      throw error;
    }
  }

  async joinEvent(input: {
    joinCodeHash: string;
    guestDisplayName: string;
    guestCapabilityHash: string;
    guestJoinBindingHash: string;
  }): Promise<JoinedEvent> {
    return this.serializable(async (transaction) => {
      const event = await transaction.event.findUnique({
        where: { joinCodeHash: input.joinCodeHash },
      });
      if (!event || event.state === PrismaEventState.EXPIRING) {
        throw new InvalidInviteError();
      }

      const existingMember = await transaction.eventMember.findUnique({
        where: {
          eventId_joinBindingHash: {
            eventId: event.id,
            joinBindingHash: input.guestJoinBindingHash,
          },
        },
      });
      const [memberCount, readyPhotoCount] = await Promise.all([
        transaction.eventMember.count({
          where: { eventId: event.id, removedAt: null },
        }),
        transaction.photo.count({
          where: { eventId: event.id, state: 'READY' },
        }),
      ]);
      if (existingMember && !existingMember.removedAt) {
        return {
          event: this.toSnapshot(event, memberCount, readyPhotoCount, {
            eventId: event.id,
            memberId: existingMember.id,
            role: 'GUEST',
          }),
          memberWasCreated: false,
        };
      }
      if (memberCount >= MAX_ACTIVE_EVENT_MEMBERS) {
        throw new EventCapacityError();
      }

      const member = await transaction.eventMember.create({
        data: {
          eventId: event.id,
          role: PrismaEventMemberRole.GUEST,
          displayName: input.guestDisplayName,
          capabilityHash: input.guestCapabilityHash,
          joinBindingHash: input.guestJoinBindingHash,
        },
      });

      return {
        event: this.toSnapshot(event, memberCount + 1, readyPhotoCount, {
          eventId: event.id,
          memberId: member.id,
          role: 'GUEST',
        }),
        memberWasCreated: true,
      };
    }, true);
  }

  async getSnapshot(eventId: string, memberId: string): Promise<EventSnapshot> {
    const [event, member, memberCount, readyPhotoCount] =
      await this.prisma.$transaction([
        this.prisma.event.findUnique({ where: { id: eventId } }),
        this.prisma.eventMember.findFirst({
          where: { id: memberId, eventId, removedAt: null },
        }),
        this.prisma.eventMember.count({
          where: { eventId, removedAt: null },
        }),
        this.prisma.photo.count({
          where: { eventId, state: 'READY' },
        }),
      ]);

    if (
      !event ||
      !member ||
      event.state === PrismaEventState.EXPIRING ||
      (event.expiresAt && event.expiresAt <= new Date())
    ) {
      throw new EventUnavailableError();
    }

    return this.toSnapshot(event, memberCount, readyPhotoCount, {
      eventId,
      memberId: member.id,
      role: member.role,
    });
  }

  async listActiveMemberCredentials(
    eventId: string,
  ): Promise<EventMemberCredential[]> {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: { state: true, expiresAt: true },
    });
    if (
      !event ||
      event.state === PrismaEventState.EXPIRING ||
      (event.expiresAt && event.expiresAt <= new Date())
    ) {
      return [];
    }

    const members = await this.prisma.eventMember.findMany({
      where: { eventId, removedAt: null },
      select: {
        id: true,
        eventId: true,
        role: true,
        capabilityHash: true,
      },
    });

    return members.map((member) => ({
      eventId: member.eventId,
      memberId: member.id,
      role: member.role,
      capabilityHash: member.capabilityHash,
    }));
  }

  async rotateJoinCode(eventId: string, joinCodeHash: string): Promise<void> {
    try {
      await this.prisma.event.update({
        where: { id: eventId },
        data: { joinCodeHash },
      });
    } catch (error) {
      if (this.isUniqueConflict(error)) {
        throw new JoinCodeConflictError();
      }
      if (this.isNotFound(error)) {
        throw new EventUnavailableError();
      }
      throw error;
    }
  }

  async endEvent(
    eventId: string,
    memberId: string,
    now: Date,
  ): Promise<EventSnapshot> {
    return this.serializable(async (transaction) => {
      const event = await transaction.event.findUnique({
        where: { id: eventId },
      });
      if (
        !event ||
        event.state === PrismaEventState.EXPIRING ||
        (event.expiresAt && event.expiresAt <= now)
      ) {
        throw new EventUnavailableError();
      }

      const ended =
        event.state === PrismaEventState.LIVE
          ? await transaction.event.update({
              where: { id: eventId },
              data: {
                state: PrismaEventState.ENDED,
                endedAt: now,
                expiresAt: new Date(now.getTime() + EVENT_RETENTION_MS),
              },
            })
          : event;
      const [memberCount, readyPhotoCount] = await Promise.all([
        transaction.eventMember.count({
          where: { eventId, removedAt: null },
        }),
        transaction.photo.count({
          where: { eventId, state: 'READY' },
        }),
      ]);

      return this.toSnapshot(ended, memberCount, readyPhotoCount, {
        eventId,
        memberId,
        role: 'HOST',
      });
    });
  }

  async restrictUploads(
    eventId: string,
    memberId: string,
    now: Date,
  ): Promise<EventSnapshot> {
    return this.serializable(async (transaction) => {
      const event = await transaction.event.findUnique({
        where: { id: eventId },
      });
      if (
        !event ||
        event.state === PrismaEventState.EXPIRING ||
        (event.expiresAt && event.expiresAt <= now)
      ) {
        throw new EventUnavailableError();
      }
      if (event.state !== PrismaEventState.ENDED) {
        throw new EventNotEndedError();
      }

      const restricted = event.uploadsRestrictedAt
        ? event
        : await transaction.event.update({
            where: { id: eventId },
            data: { uploadsRestrictedAt: now },
          });
      const [memberCount, readyPhotoCount] = await Promise.all([
        transaction.eventMember.count({
          where: { eventId, removedAt: null },
        }),
        transaction.photo.count({
          where: { eventId, state: 'READY' },
        }),
      ]);

      return this.toSnapshot(restricted, memberCount, readyPhotoCount, {
        eventId,
        memberId,
        role: 'HOST',
      });
    });
  }

  async listMembers(
    eventId: string,
    viewerMemberId: string,
  ): Promise<EventMemberSummary[]> {
    const members = await this.prisma.eventMember.findMany({
      where: { eventId, removedAt: null },
      select: { id: true, displayName: true, role: true, joinedAt: true },
      orderBy: [{ role: 'asc' }, { joinedAt: 'asc' }],
    });
    return members.map((member) => ({
      id: member.id,
      displayName: member.displayName,
      role: member.role,
      joinedAt: member.joinedAt,
      isViewer: member.id === viewerMemberId,
    }));
  }

  async updateMemberDisplayName(
    eventId: string,
    memberId: string,
    displayName: string,
  ): Promise<EventSnapshot> {
    await this.prisma.$transaction(async (transaction) => {
      const member = await transaction.eventMember.findFirst({
        where: { id: memberId, eventId, removedAt: null },
        select: { role: true },
      });
      if (!member) {
        throw new EventUnavailableError();
      }

      await transaction.eventMember.update({
        where: { id: memberId },
        data: { displayName },
      });
      if (member.role === PrismaEventMemberRole.HOST) {
        await transaction.event.update({
          where: { id: eventId },
          data: { hostDisplayName: displayName },
        });
      }
    });

    return this.getSnapshot(eventId, memberId);
  }

  async removeMember(
    eventId: string,
    targetMemberId: string,
    now: Date,
  ): Promise<void> {
    const result = await this.prisma.eventMember.updateMany({
      where: {
        id: targetMemberId,
        eventId,
        role: PrismaEventMemberRole.GUEST,
        removedAt: null,
      },
      data: {
        removedAt: now,
        liveActivityToken: null,
        joinBindingHash: null,
        capabilityHash: randomBytes(32).toString('hex'),
      },
    });
    if (result.count !== 1) {
      throw new InvalidModerationTargetError();
    }
  }

  async createHostTransfer(input: {
    eventId: string;
    tokenHash: string;
    expiresAt: Date;
  }): Promise<void> {
    await this.prisma.$transaction(async (transaction) => {
      await transaction.hostTransferToken.deleteMany({
        where: { eventId: input.eventId, consumedAt: null },
      });
      await transaction.hostTransferToken.create({
        data: input,
      });
    });
  }

  async exchangeHostTransfer(input: {
    tokenHash: string;
    replacementCapabilityHash: string;
    now: Date;
  }): Promise<EventSnapshot> {
    return this.serializable(async (transaction) => {
      const transfer = await transaction.hostTransferToken.findUnique({
        where: { tokenHash: input.tokenHash },
        include: { event: true },
      });

      if (
        !transfer ||
        transfer.consumedAt ||
        transfer.expiresAt <= input.now ||
        transfer.event.state === PrismaEventState.EXPIRING
      ) {
        throw new InvalidHostTransferError();
      }

      const host = await transaction.eventMember.findFirst({
        where: {
          eventId: transfer.eventId,
          role: PrismaEventMemberRole.HOST,
          removedAt: null,
        },
      });
      if (!host) {
        throw new InvalidHostTransferError();
      }

      await transaction.eventMember.update({
        where: { id: host.id },
        data: { capabilityHash: input.replacementCapabilityHash },
      });
      await transaction.hostTransferToken.update({
        where: { id: transfer.id },
        data: { consumedAt: input.now },
      });
      const memberCount = await transaction.eventMember.count({
        where: { eventId: transfer.eventId, removedAt: null },
      });
      const readyPhotoCount = await transaction.photo.count({
        where: { eventId: transfer.eventId, state: 'READY' },
      });

      return this.toSnapshot(transfer.event, memberCount, readyPhotoCount, {
        eventId: transfer.eventId,
        memberId: host.id,
        role: 'HOST',
      });
    });
  }

  private toSnapshot(
    event: EventRow,
    memberCount: number,
    readyPhotoCount: number,
    viewer: EventSnapshot['viewer'],
  ): EventSnapshot {
    return {
      id: event.id,
      name: event.name,
      hostDisplayName: event.hostDisplayName,
      locationLabel: event.locationLabel,
      state: event.state as EventState,
      memberCount,
      readyPhotoCount,
      createdAt: event.createdAt,
      endedAt: event.endedAt,
      expiresAt: event.expiresAt,
      uploadsRestrictedAt: event.uploadsRestrictedAt,
      viewer,
    };
  }

  private async serializable<T>(
    operation: (transaction: Prisma.TransactionClient) => Promise<T>,
    retryUniqueConflicts = false,
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
            (error.code === 'P2034' ||
              (retryUniqueConflicts && error.code === 'P2002'))
          ) ||
          attempt === SERIALIZABLE_RETRY_ATTEMPTS - 1
        ) {
          throw error;
        }
      }
    }

    throw new Error('Serializable transaction retry loop exhausted');
  }

  private isUniqueConflict(error: unknown): boolean {
    return (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    );
  }

  private isNotFound(error: unknown): boolean {
    return (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2025'
    );
  }
}

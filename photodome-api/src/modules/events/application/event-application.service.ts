import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Environment } from '../../../common/config/env.validation';
import {
  CAPABILITY_CODEC,
  type CapabilityCodec,
} from '../../capabilities/domain/capability';
import type {
  EventAccessGrant,
  EventSnapshot,
  HostAccessGrant,
  HostTransferGrant,
} from '../domain/event';
import { JoinCodeConflictError } from '../domain/event.errors';
import { JoinCodeGenerationError } from '../domain/event.errors';
import {
  EVENT_REPOSITORY,
  type EventRepository,
} from './ports/event.repository';
import {
  EVENT_REALTIME_PUBLISHER,
  type EventRealtimePublisher,
} from '../../realtime/realtime.constants';

const JOIN_CODE_GENERATION_ATTEMPTS = 5;

@Injectable()
export class EventApplicationService {
  private readonly hostTransferTtlSeconds: number;

  constructor(
    @Inject(EVENT_REPOSITORY)
    private readonly events: EventRepository,
    @Inject(CAPABILITY_CODEC)
    private readonly capabilities: CapabilityCodec,
    @Inject(EVENT_REALTIME_PUBLISHER)
    private readonly realtime: EventRealtimePublisher,
    config: ConfigService<Environment, true>,
  ) {
    this.hostTransferTtlSeconds = config.get('HOST_TRANSFER_TTL_SECONDS', {
      infer: true,
    });
  }

  async createEvent(input: {
    name: string;
    displayName: string;
    locationLabel?: string;
  }): Promise<HostAccessGrant> {
    const capability = this.capabilities.generateEventCapability();
    const hostCapabilityHash = this.capabilities.hashCapability(capability);

    for (
      let attempt = 0;
      attempt < JOIN_CODE_GENERATION_ATTEMPTS;
      attempt += 1
    ) {
      const joinCode = this.capabilities.generateJoinCode();
      try {
        const created = await this.events.createEvent({
          name: input.name.trim(),
          hostDisplayName: input.displayName.trim(),
          locationLabel: this.normalizeOptional(input.locationLabel),
          joinCodeHash: this.capabilities.hashJoinCode(joinCode),
          hostCapabilityHash,
        });
        return { event: created.event, capability, joinCode };
      } catch (error) {
        if (!(error instanceof JoinCodeConflictError)) {
          throw error;
        }
      }
    }

    throw new JoinCodeGenerationError();
  }

  async joinEvent(input: {
    joinCode: string;
    displayName: string;
  }): Promise<EventAccessGrant> {
    const capability = this.capabilities.generateEventCapability();
    const event = await this.events.joinEvent({
      joinCodeHash: this.capabilities.hashJoinCode(input.joinCode),
      guestDisplayName: input.displayName.trim(),
      guestCapabilityHash: this.capabilities.hashCapability(capability),
    });
    this.realtime.memberJoined(event.id, event.viewer.memberId);
    return { event, capability };
  }

  getSnapshot(eventId: string, memberId: string): Promise<EventSnapshot> {
    return this.events.getSnapshot(eventId, memberId);
  }

  async rotateJoinCode(
    eventId: string,
    actorMemberId: string,
  ): Promise<string> {
    for (
      let attempt = 0;
      attempt < JOIN_CODE_GENERATION_ATTEMPTS;
      attempt += 1
    ) {
      const joinCode = this.capabilities.generateJoinCode();
      try {
        await this.events.rotateJoinCode(
          eventId,
          this.capabilities.hashJoinCode(joinCode),
        );
        this.realtime.codeRotated(eventId, actorMemberId);
        return joinCode;
      } catch (error) {
        if (!(error instanceof JoinCodeConflictError)) {
          throw error;
        }
      }
    }

    throw new JoinCodeGenerationError();
  }

  async createHostTransfer(
    eventId: string,
    now: Date = new Date(),
  ): Promise<HostTransferGrant> {
    const transferToken = this.capabilities.generateTransferToken();
    const expiresAt = new Date(
      now.getTime() + this.hostTransferTtlSeconds * 1000,
    );
    await this.events.createHostTransfer({
      eventId,
      tokenHash: this.capabilities.hashTransferToken(transferToken),
      expiresAt,
    });
    return { transferToken, expiresAt };
  }

  async exchangeHostTransfer(
    transferToken: string,
    now: Date = new Date(),
  ): Promise<EventAccessGrant> {
    const capability = this.capabilities.generateEventCapability();
    const event = await this.events.exchangeHostTransfer({
      tokenHash: this.capabilities.hashTransferToken(transferToken),
      replacementCapabilityHash: this.capabilities.hashCapability(capability),
      now,
    });
    return { event, capability };
  }

  private normalizeOptional(value: string | undefined): string | null {
    const normalized = value?.trim();
    return normalized && normalized.length > 0 ? normalized : null;
  }
}

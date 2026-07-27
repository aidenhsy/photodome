import type {
  EventMemberCredential,
  EventMemberSummary,
  EventSnapshot,
} from '../../domain/event';

export interface CreatedEvent {
  event: EventSnapshot;
}

export interface JoinedEvent {
  event: EventSnapshot;
  memberWasCreated: boolean;
}

export interface EventRepository {
  createEvent(input: {
    name: string;
    hostDisplayName: string;
    locationLabel: string | null;
    joinCodeHash: string;
    hostCapabilityHash: string;
  }): Promise<CreatedEvent>;
  joinEvent(input: {
    joinCodeHash: string;
    guestDisplayName: string;
    guestCapabilityHash: string;
    guestJoinBindingHash: string;
  }): Promise<JoinedEvent>;
  getSnapshot(eventId: string, memberId: string): Promise<EventSnapshot>;
  listActiveMemberCredentials(
    eventId: string,
  ): Promise<EventMemberCredential[]>;
  rotateJoinCode(eventId: string, joinCodeHash: string): Promise<void>;
  endEvent(
    eventId: string,
    memberId: string,
    now: Date,
  ): Promise<EventSnapshot>;
  restrictUploads(
    eventId: string,
    memberId: string,
    now: Date,
  ): Promise<EventSnapshot>;
  listMembers(
    eventId: string,
    viewerMemberId: string,
  ): Promise<EventMemberSummary[]>;
  updateMemberDisplayName(
    eventId: string,
    memberId: string,
    displayName: string,
  ): Promise<EventSnapshot>;
  removeMember(
    eventId: string,
    targetMemberId: string,
    now: Date,
  ): Promise<void>;
  createHostTransfer(input: {
    eventId: string;
    tokenHash: string;
    expiresAt: Date;
  }): Promise<void>;
  exchangeHostTransfer(input: {
    tokenHash: string;
    replacementCapabilityHash: string;
    now: Date;
  }): Promise<EventSnapshot>;
}

export const EVENT_REPOSITORY = Symbol('EVENT_REPOSITORY');

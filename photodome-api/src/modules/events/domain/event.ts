import type {
  EventAccess,
  EventMemberRole,
} from '../../capabilities/domain/capability';

export type EventState = 'LIVE' | 'ENDED' | 'EXPIRING';

export interface EventSnapshot {
  id: string;
  name: string;
  hostDisplayName: string;
  locationLabel: string | null;
  state: EventState;
  memberCount: number;
  readyPhotoCount: number;
  createdAt: Date;
  endedAt: Date | null;
  expiresAt: Date | null;
  uploadsRestrictedAt: Date | null;
  viewer: EventAccess;
}

export interface EventMemberCredential {
  eventId: string;
  memberId: string;
  role: EventMemberRole;
  capabilityHash: string;
}

export interface EventMemberSummary {
  id: string;
  displayName: string;
  role: EventMemberRole;
  joinedAt: Date;
  isViewer: boolean;
}

export interface EventAccessGrant {
  event: EventSnapshot;
  capability: string;
}

export interface HostAccessGrant extends EventAccessGrant {
  joinCode: string;
}

export interface HostTransferGrant {
  transferToken: string;
  expiresAt: Date;
}

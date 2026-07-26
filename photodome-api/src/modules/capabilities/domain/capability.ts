export type EventMemberRole = 'HOST' | 'GUEST';

export interface EventAccess {
  eventId: string;
  memberId: string;
  role: EventMemberRole;
}

export interface CapabilityCodec {
  generateEventCapability(): string;
  generateTransferToken(): string;
  generateJoinCode(): string;
  normalizeJoinCode(value: string): string;
  hashCapability(value: string): string;
  hashTransferToken(value: string): string;
  hashJoinCode(value: string): string;
  matchesHash(candidateHash: string, storedHash: string): boolean;
}

export const CAPABILITY_CODEC = Symbol('CAPABILITY_CODEC');

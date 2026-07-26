import type { CleanupBacklog, CleanupTarget } from '../../domain/expiry';

export interface ExpiryRepository {
  markExpiring(eventId: string, now: Date): Promise<CleanupTarget | null>;
  beginAttempt(eventId: string, now: Date): Promise<number>;
  recordFailure(
    eventId: string,
    error: string,
    attemptedAt: Date,
  ): Promise<void>;
  finalize(eventId: string): Promise<void>;
  listDueEventIds(now: Date, limit: number): Promise<string[]>;
  listTombstonedEventIds(limit: number): Promise<string[]>;
  findExistingEventIds(eventIds: string[]): Promise<Set<string>>;
  ensureOrphanTombstone(eventId: string): Promise<boolean>;
  cleanupBacklog(now: Date): Promise<CleanupBacklog>;
}

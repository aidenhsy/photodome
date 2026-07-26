export interface CleanupTarget {
  eventId: string;
  prefix: string;
  hadEvent: boolean;
}

export interface CleanupBacklog {
  overdueEvents: number;
  oldestOverdueSeconds: number;
}

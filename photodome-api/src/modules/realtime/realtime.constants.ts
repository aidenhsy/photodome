export const EVENT_REALTIME_PUBLISHER = Symbol('EVENT_REALTIME_PUBLISHER');

export interface EventRealtimePublisher {
  photoReady(eventId: string, photoId: string): void;
  photoRemoved(eventId: string, photoId: string): void;
  eventEnded(eventId: string): void;
  uploadsRestricted(eventId: string): void;
  codeRotated(eventId: string, actorMemberId: string): void;
  memberJoined(eventId: string, memberId: string): void;
  memberUpdated(eventId: string, memberId: string): void;
  memberRemoved(eventId: string, memberId: string): Promise<void>;
  eventExpired(eventId: string): Promise<void>;
}

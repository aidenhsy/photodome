export interface EventLiveActivityPublisher {
  photoReady(eventId: string): void;
  eventEnded(eventId: string): void;
}

export const EVENT_LIVE_ACTIVITY_PUBLISHER = Symbol(
  'EVENT_LIVE_ACTIVITY_PUBLISHER',
);

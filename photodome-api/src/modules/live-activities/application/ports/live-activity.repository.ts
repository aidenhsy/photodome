export interface LiveActivityRepository {
  setToken(eventId: string, memberId: string, pushToken: string): Promise<void>;
  targets(eventId: string): Promise<string[]>;
  endedTargets(eventId: string): Promise<string[]>;
  readyPhotoCount(eventId: string): Promise<number>;
  clearTokens(pushTokens: string[]): Promise<void>;
}

export const LIVE_ACTIVITY_REPOSITORY = Symbol('LIVE_ACTIVITY_REPOSITORY');

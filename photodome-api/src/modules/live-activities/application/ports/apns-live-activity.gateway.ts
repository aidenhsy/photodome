export interface LiveActivityPushResult {
  invalid: boolean;
  error?: string;
}

export interface ApnsLiveActivityGateway {
  update(
    pushToken: string,
    contentState: Record<string, unknown>,
  ): Promise<LiveActivityPushResult>;
  end(
    pushToken: string,
    contentState: Record<string, unknown>,
  ): Promise<LiveActivityPushResult>;
}

export const APNS_LIVE_ACTIVITY_GATEWAY = Symbol('APNS_LIVE_ACTIVITY_GATEWAY');

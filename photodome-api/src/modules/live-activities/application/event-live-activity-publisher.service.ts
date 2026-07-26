import { Inject, Injectable, Logger } from '@nestjs/common';
import type { EventLiveActivityPublisher } from './live-activity.constants';
import {
  APNS_LIVE_ACTIVITY_GATEWAY,
  type ApnsLiveActivityGateway,
} from './ports/apns-live-activity.gateway';
import {
  LIVE_ACTIVITY_REPOSITORY,
  type LiveActivityRepository,
} from './ports/live-activity.repository';

@Injectable()
export class EventLiveActivityPublisherService implements EventLiveActivityPublisher {
  private readonly logger = new Logger(EventLiveActivityPublisherService.name);

  constructor(
    @Inject(LIVE_ACTIVITY_REPOSITORY)
    private readonly repository: LiveActivityRepository,
    @Inject(APNS_LIVE_ACTIVITY_GATEWAY)
    private readonly apns: ApnsLiveActivityGateway,
  ) {}

  photoReady(eventId: string): void {
    void this.publishPhotoReady(eventId).catch((error) => {
      this.logger.warn(
        `Live Activity photo-count update failed for event ${eventId}: ${String(error)}`,
      );
    });
  }

  eventEnded(eventId: string): void {
    void this.publishEventEnded(eventId).catch((error) => {
      this.logger.warn(
        `Live Activity end failed for event ${eventId}: ${String(error)}`,
      );
    });
  }

  async publishPhotoReady(eventId: string): Promise<void> {
    const [tokens, photoCount] = await Promise.all([
      this.repository.targets(eventId),
      this.repository.readyPhotoCount(eventId),
    ]);
    if (tokens.length === 0) {
      return;
    }

    const results = await Promise.all(
      tokens.map((token) =>
        this.apns.update(token, {
          photoCount,
          eventHasEnded: false,
        }),
      ),
    );
    const invalidTokens = tokens.filter((_, index) => results[index]?.invalid);
    await this.repository.clearTokens(invalidTokens);

    const succeeded = results.filter((result) => !result.error).length;
    this.logger.log(
      `Live Activity update for event ${eventId}: ${succeeded}/${results.length} accepted`,
    );
  }

  async publishEventEnded(eventId: string): Promise<void> {
    const [tokens, photoCount] = await Promise.all([
      this.repository.endedTargets(eventId),
      this.repository.readyPhotoCount(eventId),
    ]);
    if (tokens.length === 0) {
      return;
    }

    const results = await Promise.all(
      tokens.map((token) =>
        this.apns.end(token, {
          photoCount,
          eventHasEnded: true,
        }),
      ),
    );
    const completedTokens = tokens.filter(
      (_, index) => !results[index]?.error || results[index]?.invalid,
    );
    await this.repository.clearTokens(completedTokens);

    const succeeded = results.filter((result) => !result.error).length;
    this.logger.log(
      `Live Activity end for event ${eventId}: ${succeeded}/${results.length} accepted`,
    );
  }
}

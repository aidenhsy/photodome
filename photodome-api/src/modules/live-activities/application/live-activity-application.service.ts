import { Inject, Injectable } from '@nestjs/common';
import type { EventAccess } from '../../capabilities/domain/capability';
import {
  LIVE_ACTIVITY_REPOSITORY,
  type LiveActivityRepository,
} from './ports/live-activity.repository';

@Injectable()
export class LiveActivityApplicationService {
  constructor(
    @Inject(LIVE_ACTIVITY_REPOSITORY)
    private readonly repository: LiveActivityRepository,
  ) {}

  async register(access: EventAccess, pushToken: string): Promise<void> {
    await this.repository.setToken(
      access.eventId,
      access.memberId,
      pushToken.toLowerCase(),
    );
  }
}

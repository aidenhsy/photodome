import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../common/prisma/prisma.service';
import type { LiveActivityRepository } from '../application/ports/live-activity.repository';

@Injectable()
export class PrismaLiveActivityRepository implements LiveActivityRepository {
  constructor(private readonly prisma: PrismaService) {}

  async setToken(
    eventId: string,
    memberId: string,
    pushToken: string,
  ): Promise<void> {
    await this.prisma.eventMember.updateMany({
      where: { id: memberId, eventId, removedAt: null },
      data: { liveActivityToken: pushToken },
    });
  }

  async targets(eventId: string): Promise<string[]> {
    const members = await this.prisma.eventMember.findMany({
      where: {
        eventId,
        removedAt: null,
        liveActivityToken: { not: null },
        event: { state: 'LIVE' },
      },
      select: { liveActivityToken: true },
    });
    return members
      .map((member) => member.liveActivityToken)
      .filter((token): token is string => token !== null);
  }

  async endedTargets(eventId: string): Promise<string[]> {
    const members = await this.prisma.eventMember.findMany({
      where: {
        eventId,
        removedAt: null,
        liveActivityToken: { not: null },
        event: { state: 'ENDED' },
      },
      select: { liveActivityToken: true },
    });
    return members
      .map((member) => member.liveActivityToken)
      .filter((token): token is string => token !== null);
  }

  readyPhotoCount(eventId: string): Promise<number> {
    return this.prisma.photo.count({
      where: { eventId, state: 'READY' },
    });
  }

  async clearTokens(pushTokens: string[]): Promise<void> {
    if (pushTokens.length === 0) {
      return;
    }
    await this.prisma.eventMember.updateMany({
      where: { liveActivityToken: { in: pushTokens } },
      data: { liveActivityToken: null },
    });
  }
}

import { Inject, Injectable } from '@nestjs/common';
import type { EventAccess } from '../../capabilities/domain/capability';
import { EventApplicationService } from '../../events/application/event-application.service';
import {
  EVENT_REPOSITORY,
  type EventRepository,
} from '../../events/application/ports/event.repository';
import type {
  EventMemberSummary,
  EventSnapshot,
} from '../../events/domain/event';
import {
  EVENT_LIVE_ACTIVITY_PUBLISHER,
  type EventLiveActivityPublisher,
} from '../../live-activities/application/live-activity.constants';
import {
  EVENT_REALTIME_PUBLISHER,
  type EventRealtimePublisher,
} from '../../realtime/realtime.constants';
import { EventExpiryService } from '../../expiry/application/event-expiry.service';

@Injectable()
export class EventControlsApplicationService {
  constructor(
    @Inject(EVENT_REPOSITORY)
    private readonly events: EventRepository,
    private readonly eventApplication: EventApplicationService,
    @Inject(EVENT_REALTIME_PUBLISHER)
    private readonly realtime: EventRealtimePublisher,
    @Inject(EVENT_LIVE_ACTIVITY_PUBLISHER)
    private readonly liveActivities: EventLiveActivityPublisher,
    private readonly expiry: EventExpiryService,
  ) {}

  async endEvent(
    access: EventAccess,
    now: Date = new Date(),
  ): Promise<EventSnapshot> {
    const event = await this.events.endEvent(
      access.eventId,
      access.memberId,
      now,
    );
    this.realtime.eventEnded(access.eventId);
    this.liveActivities.eventEnded(access.eventId);
    if (event.expiresAt) {
      await this.expiry.schedule(event.id, event.expiresAt);
    }
    return event;
  }

  async restrictUploads(
    access: EventAccess,
    now: Date = new Date(),
  ): Promise<EventSnapshot> {
    const event = await this.events.restrictUploads(
      access.eventId,
      access.memberId,
      now,
    );
    this.realtime.uploadsRestricted(access.eventId);
    return event;
  }

  listMembers(access: EventAccess): Promise<EventMemberSummary[]> {
    return this.events.listMembers(access.eventId, access.memberId);
  }

  async updateDisplayName(
    access: EventAccess,
    displayName: string,
  ): Promise<EventSnapshot> {
    const event = await this.events.updateMemberDisplayName(
      access.eventId,
      access.memberId,
      displayName.trim(),
    );
    this.realtime.memberUpdated(access.eventId, access.memberId);
    return event;
  }

  async removeMember(
    eventId: string,
    memberId: string,
    now: Date = new Date(),
  ): Promise<void> {
    await this.events.removeMember(eventId, memberId, now);
    await this.realtime.memberRemoved(eventId, memberId);
  }

  async rotateJoinCode(access: EventAccess): Promise<string> {
    return this.eventApplication.rotateJoinCode(
      access.eventId,
      access.memberId,
    );
  }
}

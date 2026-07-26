import { Inject, Injectable } from '@nestjs/common';
import {
  CAPABILITY_CODEC,
  type CapabilityCodec,
  type EventAccess,
} from '../../capabilities/domain/capability';
import {
  EVENT_REPOSITORY,
  type EventRepository,
} from './ports/event.repository';

@Injectable()
export class EventAccessAuthorizer {
  constructor(
    @Inject(EVENT_REPOSITORY)
    private readonly events: EventRepository,
    @Inject(CAPABILITY_CODEC)
    private readonly capabilities: CapabilityCodec,
  ) {}

  async authorize(
    eventId: string,
    rawCapability: string,
  ): Promise<EventAccess | null> {
    if (!rawCapability.startsWith('pdc_')) {
      return null;
    }

    const candidateHash = this.capabilities.hashCapability(rawCapability);
    const members = await this.events.listActiveMemberCredentials(eventId);
    const matched = members.find((member) =>
      this.capabilities.matchesHash(candidateHash, member.capabilityHash),
    );
    return matched
      ? {
          eventId: matched.eventId,
          memberId: matched.memberId,
          role: matched.role,
        }
      : null;
  }
}

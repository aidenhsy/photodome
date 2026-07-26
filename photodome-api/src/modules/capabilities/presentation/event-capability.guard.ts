import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { EventMemberRole } from '../domain/capability';
import { EventAccessAuthorizer } from '../../events/application/event-access-authorizer';
import type { EventCapabilityRequest } from './event-capability.request';
import { EVENT_ROLE_METADATA } from './require-event-role.decorator';

@Injectable()
export class EventCapabilityGuard implements CanActivate {
  constructor(
    private readonly authorizer: EventAccessAuthorizer,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<EventCapabilityRequest>();
    const eventId = request.params.eventId;
    if (typeof eventId !== 'string') {
      throw new UnauthorizedException('Event access is invalid.');
    }

    const capability = this.readBearerCapability(request.headers.authorization);
    const matched = await this.authorizer.authorize(eventId, capability);
    if (!matched) {
      throw new UnauthorizedException('Event access is invalid.');
    }

    const requiredRole = this.reflector.getAllAndOverride<
      EventMemberRole | undefined
    >(EVENT_ROLE_METADATA, [context.getHandler(), context.getClass()]);
    if (requiredRole === 'HOST' && matched.role !== 'HOST') {
      throw new ForbiddenException('Host capability required.');
    }

    request.eventAccess = {
      eventId: matched.eventId,
      memberId: matched.memberId,
      role: matched.role,
    };
    return true;
  }

  private readBearerCapability(authorization: string | undefined): string {
    const [scheme, value, extra] = authorization?.split(' ') ?? [];
    if (
      scheme?.toLowerCase() !== 'bearer' ||
      !value ||
      extra ||
      !value.startsWith('pdc_')
    ) {
      throw new UnauthorizedException('Event access is invalid.');
    }
    return value;
  }
}

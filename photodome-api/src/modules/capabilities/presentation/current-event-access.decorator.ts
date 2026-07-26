import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { EventAccess } from '../domain/capability';
import type { EventCapabilityRequest } from './event-capability.request';

export const CurrentEventAccess = createParamDecorator(
  (_data: unknown, context: ExecutionContext): EventAccess => {
    const request = context.switchToHttp().getRequest<EventCapabilityRequest>();
    if (!request.eventAccess) {
      throw new Error('Event capability guard did not populate access');
    }
    return request.eventAccess;
  },
);

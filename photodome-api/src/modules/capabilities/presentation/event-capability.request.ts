import type { Request } from 'express';
import type { EventAccess } from '../domain/capability';

export interface EventCapabilityRequest extends Request {
  eventAccess?: EventAccess;
}

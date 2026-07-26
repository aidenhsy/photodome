import { SetMetadata } from '@nestjs/common';
import type { EventMemberRole } from '../domain/capability';

export const EVENT_ROLE_METADATA = 'photodome:event-role';

export const RequireEventRole = (role: EventMemberRole) =>
  SetMetadata(EVENT_ROLE_METADATA, role);

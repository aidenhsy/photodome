import { createHash } from 'node:crypto';

type UnknownRecord = Record<string, unknown>;

function isRecord(value: unknown): value is UnknownRecord {
  return typeof value === 'object' && value !== null;
}

export function ipTracker(value: unknown): string {
  if (!isRecord(value)) {
    return 'unknown';
  }
  if (typeof value.ip === 'string') {
    return value.ip;
  }
  if (
    isRecord(value.socket) &&
    typeof value.socket.remoteAddress === 'string'
  ) {
    return value.socket.remoteAddress;
  }
  return 'unknown';
}

export function installationTracker(value: unknown): string {
  if (!isRecord(value) || !isRecord(value.headers)) {
    return 'missing';
  }
  const identity = value.headers['x-photodome-installation-id'];
  return typeof identity === 'string' ? identity.slice(0, 128) : 'missing';
}

export function eventTracker(value: unknown): string {
  let signal = ipTracker(value);
  if (isRecord(value)) {
    if (isRecord(value.params) && typeof value.params.eventId === 'string') {
      signal = value.params.eventId;
    } else if (
      isRecord(value.body) &&
      typeof value.body.joinCode === 'string'
    ) {
      signal = value.body.joinCode;
    }
  }
  return createHash('sha256').update(signal.toUpperCase()).digest('hex');
}

import {
  ConnectedSocket,
  OnGatewayConnection,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import { EventAccessAuthorizer } from '../events/application/event-access-authorizer';
import type { EventRealtimePublisher } from './realtime.constants';

@WebSocketGateway({
  transports: ['websocket'],
})
export class EventGateway
  implements OnGatewayConnection, EventRealtimePublisher
{
  @WebSocketServer()
  private server!: Server;

  constructor(private readonly authorizer: EventAccessAuthorizer) {}

  async handleConnection(@ConnectedSocket() client: Socket): Promise<void> {
    const eventId = this.readString(client.handshake.auth.eventId);
    const capability = this.readString(client.handshake.auth.capability);
    if (!eventId || !capability) {
      client.disconnect(true);
      return;
    }

    const access = await this.authorizer.authorize(eventId, capability);
    if (!access) {
      client.disconnect(true);
      return;
    }

    await client.join(this.room(eventId));
    await client.join(this.memberRoom(eventId, access.memberId));
  }

  photoReady(eventId: string, photoId: string): void {
    this.server.to(this.room(eventId)).emit('event.photo_ready', {
      eventId,
      photoId,
    });
  }

  photoRemoved(eventId: string, photoId: string): void {
    this.server.to(this.room(eventId)).emit('event.photo_removed', {
      eventId,
      photoId,
    });
  }

  eventEnded(eventId: string): void {
    this.server.to(this.room(eventId)).emit('event.ended', { eventId });
  }

  uploadsRestricted(eventId: string): void {
    this.server.to(this.room(eventId)).emit('event.uploads_restricted', {
      eventId,
    });
  }

  codeRotated(eventId: string, actorMemberId: string): void {
    this.server.to(this.room(eventId)).emit('event.code_rotated', {
      eventId,
      actorMemberId,
    });
  }

  memberJoined(eventId: string, memberId: string): void {
    this.server.to(this.room(eventId)).emit('event.member_joined', {
      eventId,
      memberId,
    });
  }

  memberUpdated(eventId: string, memberId: string): void {
    this.server.to(this.room(eventId)).emit('event.member_updated', {
      eventId,
      memberId,
    });
  }

  async memberRemoved(eventId: string, memberId: string): Promise<void> {
    this.server.to(this.room(eventId)).emit('event.member_removed', {
      eventId,
      memberId,
    });
    const sockets = await this.server
      .in(this.memberRoom(eventId, memberId))
      .fetchSockets();
    for (const socket of sockets) {
      socket.disconnect(true);
    }
  }

  async eventExpired(eventId: string): Promise<void> {
    this.server.to(this.room(eventId)).emit('event.expired', { eventId });
    const sockets = await this.server.in(this.room(eventId)).fetchSockets();
    for (const socket of sockets) {
      socket.disconnect(true);
    }
  }

  private room(eventId: string): string {
    return `event:${eventId}`;
  }

  private memberRoom(eventId: string, memberId: string): string {
    return `event:${eventId}:member:${memberId}`;
  }

  private readString(value: unknown): string | null {
    return typeof value === 'string' && value.length > 0 ? value : null;
  }
}

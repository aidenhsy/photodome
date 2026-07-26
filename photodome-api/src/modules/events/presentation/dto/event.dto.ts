import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import type { EventSnapshot } from '../../domain/event';

export enum EventStateDto {
  LIVE = 'LIVE',
  ENDED = 'ENDED',
  EXPIRING = 'EXPIRING',
}

export enum EventMemberRoleDto {
  HOST = 'HOST',
  GUEST = 'GUEST',
}

export class EventViewerDto {
  @ApiProperty({ format: 'uuid' })
  memberId!: string;

  @ApiProperty({ enum: EventMemberRoleDto })
  role!: EventMemberRoleDto;
}

export class EventSnapshotDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ example: "James's birthday" })
  name!: string;

  @ApiProperty({ example: 'James' })
  hostDisplayName!: string;

  @ApiPropertyOptional({
    type: 'string',
    nullable: true,
    example: 'Shibuya',
  })
  locationLabel!: string | null;

  @ApiProperty({ enum: EventStateDto })
  state!: EventStateDto;

  @ApiProperty({ minimum: 1, maximum: 100, example: 2 })
  memberCount!: number;

  @ApiProperty({ minimum: 0, example: 24 })
  readyPhotoCount!: number;

  @ApiProperty({ example: '2026-07-25T00:00:00.000Z' })
  createdAt!: string;

  @ApiPropertyOptional({ type: 'string', nullable: true })
  endedAt!: string | null;

  @ApiPropertyOptional({ type: 'string', nullable: true })
  expiresAt!: string | null;

  @ApiPropertyOptional({ type: 'string', nullable: true })
  uploadsRestrictedAt!: string | null;

  @ApiProperty({ type: EventViewerDto })
  viewer!: EventViewerDto;

  static fromDomain(event: EventSnapshot): EventSnapshotDto {
    return {
      id: event.id,
      name: event.name,
      hostDisplayName: event.hostDisplayName,
      locationLabel: event.locationLabel,
      state: event.state as EventStateDto,
      memberCount: event.memberCount,
      readyPhotoCount: event.readyPhotoCount,
      createdAt: event.createdAt.toISOString(),
      endedAt: event.endedAt?.toISOString() ?? null,
      expiresAt: event.expiresAt?.toISOString() ?? null,
      uploadsRestrictedAt: event.uploadsRestrictedAt?.toISOString() ?? null,
      viewer: {
        memberId: event.viewer.memberId,
        role: event.viewer.role as EventMemberRoleDto,
      },
    };
  }
}

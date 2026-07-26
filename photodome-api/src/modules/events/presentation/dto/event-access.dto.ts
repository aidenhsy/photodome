import { ApiProperty } from '@nestjs/swagger';
import type { EventAccessGrant, HostAccessGrant } from '../../domain/event';
import { EventSnapshotDto } from './event.dto';

export class EventAccessDto {
  @ApiProperty({ type: EventSnapshotDto })
  event!: EventSnapshotDto;

  @ApiProperty({
    example: 'pdc_OpaqueEventCapabilityReturnedOnce',
    writeOnly: true,
  })
  capability!: string;

  static fromDomain(grant: EventAccessGrant): EventAccessDto {
    return {
      event: EventSnapshotDto.fromDomain(grant.event),
      capability: grant.capability,
    };
  }
}

export class HostEventAccessDto extends EventAccessDto {
  @ApiProperty({ example: '7JMPK4QX' })
  joinCode!: string;

  static override fromDomain(grant: HostAccessGrant): HostEventAccessDto {
    return {
      event: EventSnapshotDto.fromDomain(grant.event),
      capability: grant.capability,
      joinCode: grant.joinCode,
    };
  }
}

export class RotatedJoinCodeDto {
  @ApiProperty({ example: '8NPQ6RWT' })
  joinCode!: string;
}

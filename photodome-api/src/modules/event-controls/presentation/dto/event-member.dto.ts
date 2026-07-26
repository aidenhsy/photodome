import { ApiProperty } from '@nestjs/swagger';
import type { EventMemberSummary } from '../../../events/domain/event';
import { EventMemberRoleDto } from '../../../events/presentation/dto/event.dto';

export class EventMemberDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ example: 'Taylor' })
  displayName!: string;

  @ApiProperty({ enum: EventMemberRoleDto })
  role!: EventMemberRoleDto;

  @ApiProperty()
  joinedAt!: string;

  @ApiProperty()
  isViewer!: boolean;

  static fromDomain(member: EventMemberSummary): EventMemberDto {
    return {
      id: member.id,
      displayName: member.displayName,
      role: member.role as EventMemberRoleDto,
      joinedAt: member.joinedAt.toISOString(),
      isViewer: member.isViewer,
    };
  }
}

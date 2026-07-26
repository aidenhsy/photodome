import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length, Matches } from 'class-validator';

export class RegisterLiveActivityTokenDto {
  @ApiProperty({
    description:
      'The current ActivityKit per-activity push token as hexadecimal.',
    example: '80f2b1c3d4e5f607',
    minLength: 2,
    maxLength: 512,
  })
  @IsString()
  @Length(2, 512)
  @Matches(/^[0-9a-fA-F]+$/)
  pushToken!: string;
}

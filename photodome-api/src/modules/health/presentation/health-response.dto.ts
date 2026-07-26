import { ApiProperty } from '@nestjs/swagger';

export class HealthResponseDto {
  @ApiProperty({ enum: ['ok'], example: 'ok' })
  status!: 'ok';

  @ApiProperty({ enum: ['photodome-api'], example: 'photodome-api' })
  service!: 'photodome-api';

  @ApiProperty({ example: '0.1.0' })
  version!: string;

  @ApiProperty({ example: '2026-07-25T00:00:00.000Z' })
  timestamp!: string;
}

export class ReadinessDependenciesDto {
  @ApiProperty({ enum: ['ok', 'unavailable'], example: 'ok' })
  postgres!: 'ok' | 'unavailable';

  @ApiProperty({ enum: ['ok', 'unavailable'], example: 'ok' })
  redis!: 'ok' | 'unavailable';
}

export class ReadinessResponseDto {
  @ApiProperty({ enum: ['ready', 'unavailable'], example: 'ready' })
  status!: 'ready' | 'unavailable';

  @ApiProperty({ enum: ['photodome-api'], example: 'photodome-api' })
  service!: 'photodome-api';

  @ApiProperty({ example: '2026-07-25T00:00:00.000Z' })
  timestamp!: string;

  @ApiProperty({ type: ReadinessDependenciesDto })
  dependencies!: ReadinessDependenciesDto;
}

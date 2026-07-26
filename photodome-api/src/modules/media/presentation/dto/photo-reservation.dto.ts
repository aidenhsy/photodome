import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import type { PhotoUploadGrant } from '../../application/media-application.service';
import type { PhotoLifecycleState } from '../../domain/photo';

export class CreatePhotoReservationDto {
  @ApiProperty({ enum: ['image/jpeg'] })
  @IsIn(['image/jpeg'])
  contentType!: string;

  @ApiProperty({ minimum: 1, maximum: 20 * 1024 * 1024 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(20 * 1024 * 1024)
  byteSize!: number;

  @ApiProperty({
    pattern: '^[a-fA-F0-9]{64}$',
    description: 'SHA-256 of the exact prepared upload bytes.',
  })
  @IsString()
  @Matches(/^[a-fA-F0-9]{64}$/)
  sha256!: string;

  @ApiProperty({ minimum: 1, maximum: 20_000 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(20_000)
  width!: number;

  @ApiProperty({ minimum: 1, maximum: 20_000 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(20_000)
  height!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  capturedAt?: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 8, default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(8)
  orientation?: number;
}

export class PhotoUploadGrantDto {
  @ApiProperty({ format: 'uuid' })
  photoId!: string;

  @ApiProperty({
    description:
      'Bearer-secret GCS resumable session URI. Never log or persist outside the upload queue.',
  })
  uploadUrl!: string;

  @ApiProperty({ enum: ['image/jpeg'] })
  contentType!: string;

  @ApiProperty()
  byteSize!: number;

  @ApiProperty({
    enum: ['RESERVED', 'PROCESSING', 'READY', 'FAILED', 'REMOVED', 'EXPIRED'],
  })
  state!: PhotoLifecycleState;

  static fromDomain(grant: PhotoUploadGrant): PhotoUploadGrantDto {
    return { ...grant };
  }
}

export class PhotoCompletionDto {
  @ApiProperty({
    enum: ['RESERVED', 'PROCESSING', 'READY', 'FAILED', 'REMOVED', 'EXPIRED'],
  })
  state!: PhotoLifecycleState;
}

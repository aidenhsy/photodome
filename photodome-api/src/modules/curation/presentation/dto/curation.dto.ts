import { Transform, Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import type {
  PhotoSelection,
  PhotoSelectionDecision,
} from '../../domain/curation';
import type {
  DownloadManifestOutput,
  ReviewPageOutput,
} from '../../application/curation-application.service';

export enum PhotoSelectionDecisionDto {
  KEEP = 'KEEP',
  SKIP = 'SKIP',
}

export enum DownloadManifestModeDto {
  ALL = 'ALL',
  KEPT = 'KEPT',
}

export class SetPhotoSelectionDto {
  @ApiProperty({ enum: PhotoSelectionDecisionDto })
  @IsEnum(PhotoSelectionDecisionDto)
  decision!: PhotoSelectionDecisionDto;
}

export class PhotoSelectionDto {
  @ApiProperty({ format: 'uuid' })
  photoId!: string;

  @ApiProperty({ enum: PhotoSelectionDecisionDto })
  decision!: PhotoSelectionDecisionDto;

  @ApiProperty()
  decidedAt!: string;

  static fromDomain(selection: PhotoSelection): PhotoSelectionDto {
    return {
      photoId: selection.photoId,
      decision: selection.decision as PhotoSelectionDecisionDto,
      decidedAt: selection.decidedAt.toISOString(),
    };
  }
}

export class UndoPhotoSelectionDto {
  @ApiPropertyOptional({
    type: PhotoSelectionDto,
    nullable: true,
  })
  selection!: PhotoSelectionDto | null;
}

export class ReviewPhotosQueryDto {
  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 50, default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit = 20;
}

export class ReviewPhotoDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ format: 'uuid' })
  contributorMemberId!: string;

  @ApiProperty()
  width!: number;

  @ApiProperty()
  height!: number;

  @ApiPropertyOptional({ type: 'string', nullable: true })
  capturedAt!: string | null;

  @ApiProperty()
  readyAt!: string;

  @ApiProperty({ format: 'uri' })
  displayUrl!: string;

  @ApiProperty({ format: 'uri' })
  thumbnailUrl!: string;

  @ApiProperty()
  urlsExpireAt!: string;
}

export class ReviewPhotoPageDto {
  @ApiProperty({ type: ReviewPhotoDto, isArray: true })
  photos!: ReviewPhotoDto[];

  @ApiPropertyOptional({ type: 'string', format: 'uuid', nullable: true })
  nextCursor!: string | null;

  @ApiProperty()
  readyPhotoCount!: number;

  @ApiProperty()
  decidedPhotoCount!: number;

  @ApiProperty()
  keptPhotoCount!: number;

  static fromDomain(page: ReviewPageOutput): ReviewPhotoPageDto {
    return {
      photos: page.photos.map((photo) => ({
        id: photo.id,
        contributorMemberId: photo.contributorMemberId,
        width: photo.width,
        height: photo.height,
        capturedAt: photo.capturedAt?.toISOString() ?? null,
        readyAt: photo.readyAt.toISOString(),
        displayUrl: photo.displayUrl,
        thumbnailUrl: photo.thumbnailUrl,
        urlsExpireAt: photo.urlsExpireAt.toISOString(),
      })),
      nextCursor: page.nextCursor,
      readyPhotoCount: page.readyPhotoCount,
      decidedPhotoCount: page.decidedPhotoCount,
      keptPhotoCount: page.keptPhotoCount,
    };
  }
}

export class DownloadManifestQueryDto {
  @ApiProperty({ enum: DownloadManifestModeDto })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(DownloadManifestModeDto)
  mode!: DownloadManifestModeDto;

  @ApiPropertyOptional({
    format: 'uuid',
    description:
      'Limit the manifest to one explicitly requested photo, including the viewer’s own contribution.',
  })
  @IsOptional()
  @IsUUID()
  photoId?: string;

  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 100;
}

export class DownloadManifestPhotoDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty()
  contentType!: string;

  @ApiProperty()
  byteSize!: number;

  @ApiPropertyOptional({ type: 'string', nullable: true })
  capturedAt!: string | null;

  @ApiProperty()
  readyAt!: string;

  @ApiProperty({ format: 'uri' })
  originalUrl!: string;

  @ApiProperty()
  urlExpiresAt!: string;
}

export class DownloadManifestDto {
  @ApiProperty({ type: DownloadManifestPhotoDto, isArray: true })
  photos!: DownloadManifestPhotoDto[];

  @ApiPropertyOptional({ type: 'string', format: 'uuid', nullable: true })
  nextCursor!: string | null;

  @ApiProperty()
  totalPhotoCount!: number;

  static fromDomain(page: DownloadManifestOutput): DownloadManifestDto {
    return {
      photos: page.photos.map((photo) => ({
        id: photo.id,
        contentType: photo.contentType,
        byteSize: photo.byteSize,
        capturedAt: photo.capturedAt?.toISOString() ?? null,
        readyAt: photo.readyAt.toISOString(),
        originalUrl: photo.originalUrl,
        urlExpiresAt: photo.urlExpiresAt.toISOString(),
      })),
      nextCursor: page.nextCursor,
      totalPhotoCount: page.totalPhotoCount,
    };
  }
}

export function toDomainDecision(
  decision: PhotoSelectionDecisionDto,
): PhotoSelectionDecision {
  return decision;
}

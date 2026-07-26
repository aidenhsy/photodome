import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import type {
  AlbumPhoto,
  AlbumPhotoPage,
} from '../../application/media-application.service';

export class ListPhotosQueryDto {
  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 50;
}

export class AlbumPhotoDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ format: 'uuid' })
  contributorMemberId!: string;

  @ApiProperty()
  width!: number;

  @ApiProperty()
  height!: number;

  @ApiProperty({ type: String, nullable: true })
  capturedAt!: string | null;

  @ApiProperty()
  readyAt!: string;

  @ApiProperty()
  displayUrl!: string;

  @ApiProperty()
  thumbnailUrl!: string;

  @ApiProperty()
  urlsExpireAt!: string;

  static fromDomain(photo: AlbumPhoto): AlbumPhotoDto {
    return {
      id: photo.id,
      contributorMemberId: photo.contributorMemberId,
      width: photo.width,
      height: photo.height,
      capturedAt: photo.capturedAt?.toISOString() ?? null,
      readyAt: photo.readyAt.toISOString(),
      displayUrl: photo.displayUrl,
      thumbnailUrl: photo.thumbnailUrl,
      urlsExpireAt: photo.urlsExpireAt.toISOString(),
    };
  }
}

export class AlbumPhotoPageDto {
  @ApiProperty({ type: [AlbumPhotoDto] })
  photos!: AlbumPhotoDto[];

  @ApiProperty({ type: String, nullable: true })
  nextCursor!: string | null;

  @ApiProperty({ minimum: 0 })
  readyPhotoCount!: number;

  static fromDomain(page: AlbumPhotoPage): AlbumPhotoPageDto {
    return {
      photos: page.photos.map((photo) => AlbumPhotoDto.fromDomain(photo)),
      nextCursor: page.nextCursor,
      readyPhotoCount: page.readyPhotoCount,
    };
  }
}

import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiConflictResponse,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { EventAccess } from '../../capabilities/domain/capability';
import { CurrentEventAccess } from '../../capabilities/presentation/current-event-access.decorator';
import { EventCapabilityGuard } from '../../capabilities/presentation/event-capability.guard';
import { MediaApplicationService } from '../application/media-application.service';
import {
  CreatePhotoReservationDto,
  PhotoCompletionDto,
  PhotoUploadGrantDto,
} from './dto/photo-reservation.dto';
import { AlbumPhotoPageDto, ListPhotosQueryDto } from './dto/photo.dto';
import { MediaExceptionFilter } from './media-exception.filter';

@ApiTags('photos')
@ApiBearerAuth('eventCapability')
@Controller('events/:eventId/photos')
@UseGuards(EventCapabilityGuard)
@UseFilters(MediaExceptionFilter)
export class PhotosController {
  constructor(private readonly media: MediaApplicationService) {}

  @Get()
  @ApiOperation({
    operationId: 'listEventPhotos',
    summary: 'List ready photos with short-lived private read URLs',
  })
  @ApiOkResponse({ type: AlbumPhotoPageDto })
  async list(
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @Query() query: ListPhotosQueryDto,
  ): Promise<AlbumPhotoPageDto> {
    return AlbumPhotoPageDto.fromDomain(
      await this.media.list(eventId, query.cursor ?? null, query.limit),
    );
  }

  @Post('reservations')
  @ApiOperation({
    operationId: 'reservePhotoUpload',
    summary: 'Reserve a photo and create a direct resumable upload session',
  })
  @ApiCreatedResponse({ type: PhotoUploadGrantDto })
  @ApiConflictResponse({
    description: 'Uploads are closed or the event photo limit was reached.',
  })
  async reserve(
    @Param('eventId', ParseUUIDPipe) _eventId: string,
    @CurrentEventAccess() access: EventAccess,
    @Body() input: CreatePhotoReservationDto,
  ): Promise<PhotoUploadGrantDto> {
    return PhotoUploadGrantDto.fromDomain(
      await this.media.reserve(access, input),
    );
  }

  @Post(':photoId/upload-session')
  @HttpCode(200)
  @ApiOperation({
    operationId: 'renewPhotoUploadSession',
    summary: 'Reissue a resumable session for an owned reservation',
  })
  @ApiOkResponse({ type: PhotoUploadGrantDto })
  async renew(
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @Param('photoId', ParseUUIDPipe) photoId: string,
    @CurrentEventAccess() access: EventAccess,
  ): Promise<PhotoUploadGrantDto> {
    return PhotoUploadGrantDto.fromDomain(
      await this.media.renewUploadSession(eventId, photoId, access.memberId),
    );
  }

  @Post(':photoId/complete')
  @HttpCode(200)
  @ApiOperation({
    operationId: 'completePhotoUpload',
    summary: 'Verify an uploaded object and enqueue private image processing',
  })
  @ApiOkResponse({ type: PhotoCompletionDto })
  async complete(
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @Param('photoId', ParseUUIDPipe) photoId: string,
    @CurrentEventAccess() access: EventAccess,
  ): Promise<PhotoCompletionDto> {
    return {
      state: await this.media.complete(eventId, photoId, access.memberId),
    };
  }

  @Delete(':photoId')
  @HttpCode(204)
  @ApiOperation({
    operationId: 'removeEventPhoto',
    summary: 'Delete a ready photo contributed by the current member',
  })
  async remove(
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @Param('photoId', ParseUUIDPipe) photoId: string,
    @CurrentEventAccess() access: EventAccess,
  ): Promise<void> {
    await this.media.remove(eventId, photoId, access.memberId);
  }
}

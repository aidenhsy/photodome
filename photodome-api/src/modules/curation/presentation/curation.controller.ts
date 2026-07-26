import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Put,
  Query,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { EventAccess } from '../../capabilities/domain/capability';
import { CurrentEventAccess } from '../../capabilities/presentation/current-event-access.decorator';
import { EventCapabilityGuard } from '../../capabilities/presentation/event-capability.guard';
import { CurationApplicationService } from '../application/curation-application.service';
import { CurationExceptionFilter } from './curation-exception.filter';
import {
  DownloadManifestDto,
  DownloadManifestQueryDto,
  PhotoSelectionDto,
  ReviewPhotoPageDto,
  ReviewPhotosQueryDto,
  SetPhotoSelectionDto,
  toDomainDecision,
  UndoPhotoSelectionDto,
} from './dto/curation.dto';

@ApiTags('curation')
@ApiBearerAuth('eventCapability')
@Controller('events/:eventId')
@UseGuards(EventCapabilityGuard)
@UseFilters(CurationExceptionFilter)
export class CurationController {
  constructor(private readonly curation: CurationApplicationService) {}

  @Get('selections/review')
  @ApiOperation({
    operationId: 'getPhotoReviewQueue',
    summary: 'List this member’s remaining private review queue',
  })
  @ApiOkResponse({ type: ReviewPhotoPageDto })
  async review(
    @Param('eventId', ParseUUIDPipe) _eventId: string,
    @CurrentEventAccess() access: EventAccess,
    @Query() query: ReviewPhotosQueryDto,
  ): Promise<ReviewPhotoPageDto> {
    return ReviewPhotoPageDto.fromDomain(
      await this.curation.reviewPage(access, query.cursor ?? null, query.limit),
    );
  }

  @Put('selections/:photoId')
  @ApiOperation({
    operationId: 'setPhotoSelection',
    summary: 'Privately keep or skip one photo for this member',
  })
  @ApiOkResponse({ type: PhotoSelectionDto })
  async setSelection(
    @Param('eventId', ParseUUIDPipe) _eventId: string,
    @Param('photoId', ParseUUIDPipe) photoId: string,
    @CurrentEventAccess() access: EventAccess,
    @Body() input: SetPhotoSelectionDto,
  ): Promise<PhotoSelectionDto> {
    return PhotoSelectionDto.fromDomain(
      await this.curation.setSelection(
        access,
        photoId,
        toDomainDecision(input.decision),
      ),
    );
  }

  @Delete('selections/latest')
  @HttpCode(200)
  @ApiOperation({
    operationId: 'undoLatestSelection',
    summary: 'Undo this member’s most recent private decision',
  })
  @ApiOkResponse({ type: UndoPhotoSelectionDto })
  async undo(
    @Param('eventId', ParseUUIDPipe) _eventId: string,
    @CurrentEventAccess() access: EventAccess,
  ): Promise<UndoPhotoSelectionDto> {
    const selection = await this.curation.undoLatest(access);
    return {
      selection: selection ? PhotoSelectionDto.fromDomain(selection) : null,
    };
  }

  @Get('download-manifest')
  @ApiOperation({
    operationId: 'getDownloadManifest',
    summary: 'Get paginated short-lived signed original URLs',
  })
  @ApiOkResponse({ type: DownloadManifestDto })
  async manifest(
    @Param('eventId', ParseUUIDPipe) _eventId: string,
    @CurrentEventAccess() access: EventAccess,
    @Query() query: DownloadManifestQueryDto,
  ): Promise<DownloadManifestDto> {
    return DownloadManifestDto.fromDomain(
      await this.curation.downloadManifest(
        access,
        query.mode,
        query.cursor ?? null,
        query.limit,
        query.photoId ?? null,
      ),
    );
  }
}

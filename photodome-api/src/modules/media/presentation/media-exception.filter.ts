import {
  ArgumentsHost,
  BadRequestException,
  Catch,
  ConflictException,
  ExceptionFilter,
  NotFoundException,
} from '@nestjs/common';
import type { Response } from 'express';
import {
  InvalidPhotoReservationError,
  PhotoCapacityError,
  UploadedObjectMismatchError,
  UploadedObjectMissingError,
  UploadAdmissionClosedError,
} from '../domain/media.errors';

type MediaDomainError =
  | InvalidPhotoReservationError
  | PhotoCapacityError
  | UploadedObjectMismatchError
  | UploadedObjectMissingError
  | UploadAdmissionClosedError;

@Catch(
  InvalidPhotoReservationError,
  PhotoCapacityError,
  UploadedObjectMismatchError,
  UploadedObjectMissingError,
  UploadAdmissionClosedError,
)
export class MediaExceptionFilter implements ExceptionFilter<MediaDomainError> {
  catch(exception: MediaDomainError, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    const mapped = this.map(exception);
    response.status(mapped.getStatus()).json(mapped.getResponse());
  }

  private map(exception: MediaDomainError) {
    if (exception instanceof PhotoCapacityError) {
      return new ConflictException('This event has reached its photo limit.');
    }
    if (exception instanceof UploadAdmissionClosedError) {
      return new ConflictException('This event is not accepting new uploads.');
    }
    if (
      exception instanceof UploadedObjectMissingError ||
      exception instanceof UploadedObjectMismatchError
    ) {
      return new ConflictException(
        'The uploaded file does not match its reservation.',
      );
    }
    if (exception instanceof InvalidPhotoReservationError) {
      return new NotFoundException('This photo reservation is unavailable.');
    }
    return new BadRequestException('The photo request is invalid.');
  }
}

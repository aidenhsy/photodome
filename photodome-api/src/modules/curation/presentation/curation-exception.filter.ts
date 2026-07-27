import {
  ArgumentsHost,
  Catch,
  ConflictException,
  ExceptionFilter,
  NotFoundException,
} from '@nestjs/common';
import type { Response } from 'express';
import {
  CurationUnavailableError,
  SelectionPhotoUnavailableError,
} from '../domain/curation.errors';

type CurationDomainError =
  | CurationUnavailableError
  | SelectionPhotoUnavailableError;

@Catch(CurationUnavailableError, SelectionPhotoUnavailableError)
export class CurationExceptionFilter implements ExceptionFilter<CurationDomainError> {
  catch(exception: CurationDomainError, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    const mapped =
      exception instanceof CurationUnavailableError
        ? new ConflictException(
            'Photo take-home is unavailable because this event has expired.',
          )
        : new NotFoundException('This photo is unavailable.');
    response.status(mapped.getStatus()).json(mapped.getResponse());
  }
}

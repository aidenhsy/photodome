import {
  ArgumentsHost,
  Catch,
  ConflictException,
  ExceptionFilter,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { Response } from 'express';
import {
  EventCapacityError,
  EventNotEndedError,
  EventUnavailableError,
  InvalidModerationTargetError,
  InvalidHostTransferError,
  InvalidInviteError,
  JoinCodeGenerationError,
} from '../domain/event.errors';

type EventDomainError =
  | EventCapacityError
  | EventUnavailableError
  | EventNotEndedError
  | InvalidModerationTargetError
  | InvalidHostTransferError
  | InvalidInviteError
  | JoinCodeGenerationError;

@Catch(
  EventCapacityError,
  EventUnavailableError,
  EventNotEndedError,
  InvalidModerationTargetError,
  InvalidHostTransferError,
  InvalidInviteError,
  JoinCodeGenerationError,
)
export class EventDomainExceptionFilter implements ExceptionFilter<EventDomainError> {
  catch(exception: EventDomainError, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    const mapped = this.mapException(exception);
    response.status(mapped.getStatus()).json(mapped.getResponse());
  }

  private mapException(exception: EventDomainError) {
    if (exception instanceof EventCapacityError) {
      return new ConflictException('This event is full.');
    }
    if (exception instanceof JoinCodeGenerationError) {
      return new ServiceUnavailableException(
        'Could not create an invite code. Try again.',
      );
    }
    if (exception instanceof EventUnavailableError) {
      return new NotFoundException('This event is unavailable.');
    }
    if (exception instanceof EventNotEndedError) {
      return new ConflictException(
        'End the event before restricting new uploads.',
      );
    }
    if (exception instanceof InvalidModerationTargetError) {
      return new NotFoundException('This attendee is unavailable.');
    }
    return new NotFoundException(
      'This invite is invalid or no longer available.',
    );
  }
}

import type { Queue } from 'bullmq';
import type { ObjectStorageGateway } from '../../media/application/ports/object-storage.gateway';
import type { EventRealtimePublisher } from '../../realtime/realtime.constants';
import { EventExpiryService } from './event-expiry.service';
import type { ExpiryMetricsService } from './expiry-metrics.service';
import type { ExpiryRepository } from './ports/expiry.repository';

/* eslint-disable @typescript-eslint/unbound-method */

describe('EventExpiryService', () => {
  const eventId = '43c38c53-591f-46b1-8bb3-cce980ff62d8';
  let repository: jest.Mocked<ExpiryRepository>;
  let storage: jest.Mocked<ObjectStorageGateway>;
  let realtime: jest.Mocked<EventRealtimePublisher>;
  let queue: jest.Mocked<Pick<Queue, 'add'>>;
  let metrics: jest.Mocked<
    Pick<
      ExpiryMetricsService,
      | 'cleanupSucceeded'
      | 'cleanupFailed'
      | 'orphanDiscovered'
      | 'reconciliationFinished'
    >
  >;
  let service: EventExpiryService;

  beforeEach(() => {
    repository = {
      markExpiring: jest.fn(),
      beginAttempt: jest.fn(),
      recordFailure: jest.fn(),
      finalize: jest.fn(),
      listDueEventIds: jest.fn(),
      listTombstonedEventIds: jest.fn(),
      findExistingEventIds: jest.fn(),
      ensureOrphanTombstone: jest.fn(),
      cleanupBacklog: jest.fn(),
    };
    storage = {
      createUploadSession: jest.fn(),
      inspectUploadedObject: jest.fn(),
      processVariants: jest.fn(),
      createReadUrl: jest.fn(),
      deletePhotoObjects: jest.fn(),
      photoObjectsExist: jest.fn(),
      deleteEventPrefix: jest.fn(),
      eventPrefixObjectsExist: jest.fn(),
      listStoredEventIds: jest.fn(),
    };
    realtime = {
      photoReady: jest.fn(),
      photoRemoved: jest.fn(),
      eventEnded: jest.fn(),
      uploadsRestricted: jest.fn(),
      codeRotated: jest.fn(),
      memberJoined: jest.fn(),
      memberUpdated: jest.fn(),
      memberRemoved: jest.fn(),
      eventExpired: jest.fn(),
    };
    queue = { add: jest.fn() };
    metrics = {
      cleanupSucceeded: jest.fn(),
      cleanupFailed: jest.fn(),
      orphanDiscovered: jest.fn(),
      reconciliationFinished: jest.fn(),
    };
    service = new EventExpiryService(
      repository,
      storage,
      realtime,
      queue as unknown as Queue,
      metrics as unknown as ExpiryMetricsService,
    );
  });

  it('retains the tombstone on failure and finishes idempotently on retry', async () => {
    repository.markExpiring.mockResolvedValue({
      eventId,
      prefix: `events/${eventId}/`,
      hadEvent: true,
    });
    repository.beginAttempt.mockResolvedValueOnce(1).mockResolvedValueOnce(2);
    storage.deleteEventPrefix
      .mockRejectedValueOnce(new Error('temporary GCS failure'))
      .mockResolvedValueOnce({ objectsDeleted: 3, bytesDeleted: 1_024 });
    storage.eventPrefixObjectsExist.mockResolvedValue(false);

    await expect(service.cleanup(eventId)).rejects.toThrow(
      'temporary GCS failure',
    );
    expect(repository.recordFailure).toHaveBeenCalledWith(
      eventId,
      'temporary GCS failure',
      expect.any(Date),
    );
    expect(repository.finalize).not.toHaveBeenCalled();

    await expect(service.cleanup(eventId)).resolves.toBeUndefined();
    expect(repository.finalize).toHaveBeenCalledWith(eventId);
    expect(realtime.eventExpired).toHaveBeenCalledTimes(2);
    expect(metrics.cleanupSucceeded).toHaveBeenCalledWith(
      3,
      1_024,
      expect.any(Number),
    );
  });

  it('reconciles overdue events, tombstones, and orphan prefixes', async () => {
    const overdueId = '2c7c53ca-2b9e-4c02-b96c-43f6178b7634';
    const tombstoneId = 'a6abaf89-9b18-4436-a2c2-d8954d0600df';
    repository.listDueEventIds.mockResolvedValue([overdueId]);
    repository.listTombstonedEventIds.mockResolvedValue([tombstoneId]);
    repository.findExistingEventIds.mockResolvedValue(new Set());
    repository.ensureOrphanTombstone.mockResolvedValue(true);
    storage.listStoredEventIds.mockResolvedValue([eventId]);

    await service.reconcile();

    expect(metrics.orphanDiscovered).toHaveBeenCalledTimes(1);
    expect(queue.add).toHaveBeenCalledTimes(3);
    expect(metrics.reconciliationFinished).toHaveBeenCalledWith(true);
  });
});

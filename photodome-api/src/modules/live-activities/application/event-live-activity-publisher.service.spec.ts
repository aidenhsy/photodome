import type { ApnsLiveActivityGateway } from './ports/apns-live-activity.gateway';
import type { LiveActivityRepository } from './ports/live-activity.repository';
import { EventLiveActivityPublisherService } from './event-live-activity-publisher.service';

describe('EventLiveActivityPublisherService', () => {
  it('publishes the exact ActivityKit content-state and clears invalid tokens', async () => {
    const clearTokens = jest.fn().mockResolvedValue(undefined);
    const update = jest
      .fn()
      .mockResolvedValueOnce({ invalid: false })
      .mockResolvedValueOnce({
        invalid: true,
        error: 'Unregistered',
      });
    const repository: jest.Mocked<LiveActivityRepository> = {
      setToken: jest.fn(),
      targets: jest.fn().mockResolvedValue(['valid-token', 'stale-token']),
      endedTargets: jest.fn(),
      readyPhotoCount: jest.fn().mockResolvedValue(12),
      clearTokens,
    };
    const apns: jest.Mocked<ApnsLiveActivityGateway> = {
      update,
      end: jest.fn(),
    };
    const service = new EventLiveActivityPublisherService(repository, apns);

    await service.publishPhotoReady('event-id');

    expect(update).toHaveBeenNthCalledWith(1, 'valid-token', {
      photoCount: 12,
      eventHasEnded: false,
    });
    expect(update).toHaveBeenNthCalledWith(2, 'stale-token', {
      photoCount: 12,
      eventHasEnded: false,
    });
    expect(clearTokens).toHaveBeenCalledWith(['stale-token']);
  });

  it('ends every ActivityKit surface with the final photo count', async () => {
    const clearTokens = jest.fn().mockResolvedValue(undefined);
    const end = jest
      .fn()
      .mockResolvedValueOnce({ invalid: false })
      .mockResolvedValueOnce({
        invalid: false,
        error: 'APNs request timed out',
      });
    const repository: jest.Mocked<LiveActivityRepository> = {
      setToken: jest.fn(),
      targets: jest.fn(),
      endedTargets: jest.fn().mockResolvedValue(['accepted', 'retry-later']),
      readyPhotoCount: jest.fn().mockResolvedValue(27),
      clearTokens,
    };
    const apns: jest.Mocked<ApnsLiveActivityGateway> = {
      update: jest.fn(),
      end,
    };
    const service = new EventLiveActivityPublisherService(repository, apns);

    await service.publishEventEnded('event-id');

    expect(end).toHaveBeenNthCalledWith(1, 'accepted', {
      photoCount: 27,
      eventHasEnded: true,
    });
    expect(end).toHaveBeenNthCalledWith(2, 'retry-later', {
      photoCount: 27,
      eventHasEnded: true,
    });
    expect(clearTokens).toHaveBeenCalledWith(['accepted']);
  });
});

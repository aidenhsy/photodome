import { GetHealthUseCase } from './get-health.use-case';

describe('GetHealthUseCase', () => {
  it('returns a stable health payload', () => {
    const now = new Date('2026-07-25T00:00:00.000Z');

    expect(new GetHealthUseCase().execute(now)).toEqual({
      status: 'ok',
      service: 'photodome-api',
      version: '0.1.0',
      timestamp: '2026-07-25T00:00:00.000Z',
    });
  });
});

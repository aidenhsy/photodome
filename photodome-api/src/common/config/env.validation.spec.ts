import { validateEnvironment } from './env.validation';

const safeProductionEnvironment = {
  NODE_ENV: 'production',
  PORT: '3000',
  DATABASE_URL: 'postgresql://app:secret@database:5432/photodome',
  REDIS_URL: 'rediss://redis:6379',
  LOG_LEVEL: 'info',
  CORS_ALLOWED_ORIGINS: '',
  CAPABILITY_PEPPER: 'production-capability-pepper-at-least-32-characters',
  HOST_TRANSFER_TTL_SECONDS: '600',
  GCS_PROJECT_ID: 'photodome-production',
  MEDIA_BUCKET_NAME: 'photodome-media-production',
  GCS_API_ENDPOINT: '',
  SIGNED_URL_TTL_SECONDS: '300',
  CLEANUP_RECONCILIATION_INTERVAL_SECONDS: '300',
  METRICS_BEARER_TOKEN: 'production-metrics-token-at-least-32-characters',
  APNS_ENVIRONMENT: 'production',
  APNS_BUNDLE_ID: 'com.younger7jp.photodome',
  APNS_TEAM_ID: 'TEAM123456',
  APNS_KEY_ID: 'KEY1234567',
  APNS_PRIVATE_KEY: 'private-key-material',
};

describe('validateEnvironment production safety', () => {
  it('accepts a complete production configuration', () => {
    expect(validateEnvironment(safeProductionEnvironment)).toMatchObject({
      NODE_ENV: 'production',
      GCS_API_ENDPOINT: '',
      APNS_ENVIRONMENT: 'production',
    });
  });

  it.each([
    [
      'a storage emulator',
      { GCS_API_ENDPOINT: 'http://127.0.0.1:4443' },
      'GCS_API_ENDPOINT',
    ],
    ['an absent metrics token', { METRICS_BEARER_TOKEN: '' }, 'METRICS'],
    [
      'the development capability pepper',
      {
        CAPABILITY_PEPPER: 'local-development-capability-pepper-change-me',
      },
      'CAPABILITY_PEPPER',
    ],
    ['debug logging', { LOG_LEVEL: 'debug' }, 'LOG_LEVEL'],
    ['sandbox APNs', { APNS_ENVIRONMENT: 'sandbox' }, 'APNS_ENVIRONMENT'],
    ['missing APNs credentials', { APNS_KEY_ID: '' }, 'APNS'],
  ])('rejects production with %s', (_label, override, message) => {
    expect(() =>
      validateEnvironment({
        ...safeProductionEnvironment,
        ...override,
      }),
    ).toThrow(message);
  });
});

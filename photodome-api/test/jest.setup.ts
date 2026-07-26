process.env.NODE_ENV = 'test';
process.env.PORT = '3000';
process.env.DATABASE_URL =
  'postgresql://photodome:photodome@localhost:5434/photodome_test?schema=public';
process.env.REDIS_URL = 'redis://localhost:6381/15';
process.env.LOG_LEVEL = 'silent';
process.env.CORS_ALLOWED_ORIGINS = '';
process.env.CAPABILITY_PEPPER =
  'test-only-capability-pepper-at-least-32-characters';
process.env.HOST_TRANSFER_TTL_SECONDS = '600';
process.env.GCS_PROJECT_ID = 'photodome-test';
process.env.MEDIA_BUCKET_NAME = 'photodome-media-dev';
process.env.GCS_API_ENDPOINT = 'http://127.0.0.1:4443';
process.env.SIGNED_URL_TTL_SECONDS = '300';
process.env.CLEANUP_RECONCILIATION_INTERVAL_SECONDS = '10';
process.env.METRICS_BEARER_TOKEN =
  'test-only-metrics-token-at-least-32-characters';

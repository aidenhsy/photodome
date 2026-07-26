export type NodeEnvironment = 'development' | 'test' | 'production';

export interface Environment {
  NODE_ENV: NodeEnvironment;
  PORT: number;
  DATABASE_URL: string;
  REDIS_URL: string;
  LOG_LEVEL: string;
  CORS_ALLOWED_ORIGINS: string;
  CAPABILITY_PEPPER: string;
  HOST_TRANSFER_TTL_SECONDS: number;
  GCS_PROJECT_ID: string;
  MEDIA_BUCKET_NAME: string;
  GCS_API_ENDPOINT: string;
  SIGNED_URL_TTL_SECONDS: number;
  CLEANUP_RECONCILIATION_INTERVAL_SECONDS: number;
  METRICS_BEARER_TOKEN?: string;
  APNS_ENVIRONMENT: 'sandbox' | 'production';
  APNS_BUNDLE_ID?: string;
  APNS_TEAM_ID?: string;
  APNS_KEY_ID?: string;
  APNS_PRIVATE_KEY?: string;
}

const VALID_NODE_ENVIRONMENTS = new Set<NodeEnvironment>([
  'development',
  'test',
  'production',
]);

function requireUrl(
  input: Record<string, unknown>,
  key: 'DATABASE_URL' | 'REDIS_URL',
): string {
  const value = input[key];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`${key} is required`);
  }

  try {
    new URL(value);
  } catch {
    throw new Error(`${key} must be a valid URL`);
  }

  return value;
}

export function validateEnvironment(
  input: Record<string, unknown>,
): Environment {
  const rawNodeEnvironment = input.NODE_ENV ?? 'development';
  if (
    typeof rawNodeEnvironment !== 'string' ||
    !VALID_NODE_ENVIRONMENTS.has(rawNodeEnvironment as NodeEnvironment)
  ) {
    throw new Error('NODE_ENV must be development, test, or production');
  }

  const rawPort = input.PORT ?? '3000';
  const port = Number(rawPort);
  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error('PORT must be an integer between 1 and 65535');
  }

  const capabilityPepper = input.CAPABILITY_PEPPER;
  if (typeof capabilityPepper !== 'string' || capabilityPepper.length < 32) {
    throw new Error('CAPABILITY_PEPPER must contain at least 32 characters');
  }

  const hostTransferTtlSeconds = Number(
    input.HOST_TRANSFER_TTL_SECONDS ?? '600',
  );
  if (
    !Number.isInteger(hostTransferTtlSeconds) ||
    hostTransferTtlSeconds < 60 ||
    hostTransferTtlSeconds > 3600
  ) {
    throw new Error(
      'HOST_TRANSFER_TTL_SECONDS must be an integer from 60 to 3600',
    );
  }

  const gcsProjectId = input.GCS_PROJECT_ID;
  if (typeof gcsProjectId !== 'string' || gcsProjectId.trim().length === 0) {
    throw new Error('GCS_PROJECT_ID is required');
  }

  const mediaBucketName = input.MEDIA_BUCKET_NAME;
  if (
    typeof mediaBucketName !== 'string' ||
    !/^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$/.test(mediaBucketName)
  ) {
    throw new Error('MEDIA_BUCKET_NAME must be a valid GCS bucket name');
  }

  const gcsApiEndpoint =
    typeof input.GCS_API_ENDPOINT === 'string'
      ? input.GCS_API_ENDPOINT.trim()
      : '';
  if (gcsApiEndpoint.length > 0) {
    try {
      new URL(gcsApiEndpoint);
    } catch {
      throw new Error('GCS_API_ENDPOINT must be a valid URL');
    }
  }

  const signedUrlTtlSeconds = Number(input.SIGNED_URL_TTL_SECONDS ?? '300');
  if (
    !Number.isInteger(signedUrlTtlSeconds) ||
    signedUrlTtlSeconds < 60 ||
    signedUrlTtlSeconds > 900
  ) {
    throw new Error('SIGNED_URL_TTL_SECONDS must be an integer from 60 to 900');
  }

  const cleanupReconciliationIntervalSeconds = Number(
    input.CLEANUP_RECONCILIATION_INTERVAL_SECONDS ?? '300',
  );
  if (
    !Number.isInteger(cleanupReconciliationIntervalSeconds) ||
    cleanupReconciliationIntervalSeconds < 10 ||
    cleanupReconciliationIntervalSeconds > 86_400
  ) {
    throw new Error(
      'CLEANUP_RECONCILIATION_INTERVAL_SECONDS must be an integer from 10 to 86400',
    );
  }
  const metricsBearerToken =
    typeof input.METRICS_BEARER_TOKEN === 'string' &&
    input.METRICS_BEARER_TOKEN.length > 0
      ? input.METRICS_BEARER_TOKEN
      : undefined;
  if (metricsBearerToken && metricsBearerToken.length < 32) {
    throw new Error(
      'METRICS_BEARER_TOKEN must contain at least 32 characters when configured',
    );
  }

  const apnsEnvironment = input.APNS_ENVIRONMENT ?? 'sandbox';
  if (apnsEnvironment !== 'sandbox' && apnsEnvironment !== 'production') {
    throw new Error('APNS_ENVIRONMENT must be sandbox or production');
  }
  const apnsKeys = [
    'APNS_BUNDLE_ID',
    'APNS_TEAM_ID',
    'APNS_KEY_ID',
    'APNS_PRIVATE_KEY',
  ] as const;
  const apnsValues = Object.fromEntries(
    apnsKeys.map((key) => [
      key,
      typeof input[key] === 'string' && input[key].trim().length > 0
        ? input[key].trim()
        : undefined,
    ]),
  ) as Record<(typeof apnsKeys)[number], string | undefined>;
  const configuredApnsValues = Object.values(apnsValues).filter(Boolean);
  if (
    configuredApnsValues.length > 0 &&
    configuredApnsValues.length !== apnsKeys.length
  ) {
    throw new Error(
      'APNS_BUNDLE_ID, APNS_TEAM_ID, APNS_KEY_ID, and APNS_PRIVATE_KEY must be configured together',
    );
  }
  if (rawNodeEnvironment === 'production') {
    if (gcsApiEndpoint.length > 0) {
      throw new Error('GCS_API_ENDPOINT must be empty in production');
    }
    if (!metricsBearerToken) {
      throw new Error('METRICS_BEARER_TOKEN is required in production');
    }
    if (capabilityPepper === 'local-development-capability-pepper-change-me') {
      throw new Error(
        'CAPABILITY_PEPPER must not use the development default in production',
      );
    }
    const logLevel =
      typeof input.LOG_LEVEL === 'string' ? input.LOG_LEVEL : 'info';
    if (logLevel === 'debug' || logLevel === 'trace') {
      throw new Error('LOG_LEVEL must not be debug or trace in production');
    }
    if (apnsEnvironment !== 'production') {
      throw new Error('APNS_ENVIRONMENT must be production in production');
    }
    if (configuredApnsValues.length !== apnsKeys.length) {
      throw new Error(
        'ActivityKit APNs credentials are required in production',
      );
    }
  }

  return {
    NODE_ENV: rawNodeEnvironment as NodeEnvironment,
    PORT: port,
    DATABASE_URL: requireUrl(input, 'DATABASE_URL'),
    REDIS_URL: requireUrl(input, 'REDIS_URL'),
    LOG_LEVEL:
      typeof input.LOG_LEVEL === 'string' && input.LOG_LEVEL.length > 0
        ? input.LOG_LEVEL
        : 'info',
    CORS_ALLOWED_ORIGINS:
      typeof input.CORS_ALLOWED_ORIGINS === 'string'
        ? input.CORS_ALLOWED_ORIGINS
        : '',
    CAPABILITY_PEPPER: capabilityPepper,
    HOST_TRANSFER_TTL_SECONDS: hostTransferTtlSeconds,
    GCS_PROJECT_ID: gcsProjectId,
    MEDIA_BUCKET_NAME: mediaBucketName,
    GCS_API_ENDPOINT: gcsApiEndpoint,
    SIGNED_URL_TTL_SECONDS: signedUrlTtlSeconds,
    CLEANUP_RECONCILIATION_INTERVAL_SECONDS:
      cleanupReconciliationIntervalSeconds,
    ...(metricsBearerToken ? { METRICS_BEARER_TOKEN: metricsBearerToken } : {}),
    APNS_ENVIRONMENT: apnsEnvironment,
    ...(apnsValues.APNS_BUNDLE_ID
      ? { APNS_BUNDLE_ID: apnsValues.APNS_BUNDLE_ID }
      : {}),
    ...(apnsValues.APNS_TEAM_ID
      ? { APNS_TEAM_ID: apnsValues.APNS_TEAM_ID }
      : {}),
    ...(apnsValues.APNS_KEY_ID ? { APNS_KEY_ID: apnsValues.APNS_KEY_ID } : {}),
    ...(apnsValues.APNS_PRIVATE_KEY
      ? {
          APNS_PRIVATE_KEY: apnsValues.APNS_PRIVATE_KEY.replace(/\\n/g, '\n'),
        }
      : {}),
  };
}

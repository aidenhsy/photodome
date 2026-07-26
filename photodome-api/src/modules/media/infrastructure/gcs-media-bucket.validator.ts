import { Storage } from '@google-cloud/storage';
import { Injectable, type OnApplicationBootstrap } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Environment } from '../../../common/config/env.validation';

const PUBLIC_IAM_MEMBERS = new Set(['allUsers', 'allAuthenticatedUsers']);

interface MediaBucketMetadata {
  iamConfiguration?: {
    uniformBucketLevelAccess?: { enabled?: boolean | null } | null;
    publicAccessPrevention?: string | null;
  } | null;
  versioning?: { enabled?: boolean | null } | null;
  softDeletePolicy?: {
    retentionDurationSeconds?: string | number | null;
  } | null;
  retentionPolicy?: { retentionPeriod?: string | number | null } | null;
  defaultEventBasedHold?: boolean | null;
}

interface MediaBucketPolicy {
  bindings?: Array<{ members?: string[] | null }> | null;
}

export function findMediaBucketPolicyViolations(
  metadata: MediaBucketMetadata,
  policy: MediaBucketPolicy,
): string[] {
  const violations: string[] = [];
  if (!metadata.iamConfiguration?.uniformBucketLevelAccess?.enabled) {
    violations.push('uniform bucket-level access is not enabled');
  }
  if (
    metadata.iamConfiguration?.publicAccessPrevention?.toLowerCase() !==
    'enforced'
  ) {
    violations.push('public access prevention is not enforced');
  }
  if (
    policy.bindings?.some((binding) =>
      binding.members?.some((member) => PUBLIC_IAM_MEMBERS.has(member)),
    )
  ) {
    violations.push('a public IAM principal is present');
  }
  if (metadata.versioning?.enabled) {
    violations.push('object versioning is enabled');
  }
  if (Number(metadata.softDeletePolicy?.retentionDurationSeconds ?? 0) > 0) {
    violations.push('soft delete is enabled');
  }
  if (Number(metadata.retentionPolicy?.retentionPeriod ?? 0) > 0) {
    violations.push('a bucket retention policy is enabled');
  }
  if (metadata.defaultEventBasedHold) {
    violations.push('default event-based hold is enabled');
  }
  return violations;
}

@Injectable()
export class GcsMediaBucketValidator implements OnApplicationBootstrap {
  constructor(private readonly config: ConfigService<Environment, true>) {}

  async onApplicationBootstrap(): Promise<void> {
    const apiEndpoint = this.config.get('GCS_API_ENDPOINT', { infer: true });
    if (apiEndpoint) {
      return;
    }

    const projectId = this.config.get('GCS_PROJECT_ID', { infer: true });
    const bucketName = this.config.get('MEDIA_BUCKET_NAME', { infer: true });
    const storage = new Storage({ projectId });
    const bucket = storage.bucket(bucketName);
    const [[metadata], [policy]] = await Promise.all([
      bucket.getMetadata(),
      bucket.iam.getPolicy({ requestedPolicyVersion: 3 }),
    ]);

    const violations = findMediaBucketPolicyViolations(metadata, policy);

    if (violations.length > 0) {
      throw new Error(
        `MEDIA_BUCKET_NAME is not safe for seven-day permanent deletion: ${violations.join(
          '; ',
        )}`,
      );
    }
  }
}

import { findMediaBucketPolicyViolations } from './gcs-media-bucket.validator';

describe('findMediaBucketPolicyViolations', () => {
  const safeMetadata = {
    iamConfiguration: {
      uniformBucketLevelAccess: { enabled: true },
      publicAccessPrevention: 'enforced',
    },
    versioning: { enabled: false },
    softDeletePolicy: { retentionDurationSeconds: '0' },
    defaultEventBasedHold: false,
  };

  it('accepts the permanent-deletion bucket policy', () => {
    expect(
      findMediaBucketPolicyViolations(safeMetadata, { bindings: [] }),
    ).toEqual([]);
  });

  it.each([
    [
      'public IAM',
      safeMetadata,
      { bindings: [{ members: ['allUsers'] }] },
      'a public IAM principal is present',
    ],
    [
      'versioning',
      { ...safeMetadata, versioning: { enabled: true } },
      { bindings: [] },
      'object versioning is enabled',
    ],
    [
      'soft delete',
      {
        ...safeMetadata,
        softDeletePolicy: { retentionDurationSeconds: '604800' },
      },
      { bindings: [] },
      'soft delete is enabled',
    ],
    [
      'retention policy',
      { ...safeMetadata, retentionPolicy: { retentionPeriod: '86400' } },
      { bindings: [] },
      'a bucket retention policy is enabled',
    ],
    [
      'default hold',
      { ...safeMetadata, defaultEventBasedHold: true },
      { bindings: [] },
      'default event-based hold is enabled',
    ],
    [
      'non-uniform access',
      {
        ...safeMetadata,
        iamConfiguration: {
          ...safeMetadata.iamConfiguration,
          uniformBucketLevelAccess: { enabled: false },
        },
      },
      { bindings: [] },
      'uniform bucket-level access is not enabled',
    ],
    [
      'unenforced public access prevention',
      {
        ...safeMetadata,
        iamConfiguration: {
          ...safeMetadata.iamConfiguration,
          publicAccessPrevention: 'inherited',
        },
      },
      { bindings: [] },
      'public access prevention is not enforced',
    ],
  ])('rejects %s', (_name, metadata, policy, expected) => {
    expect(findMediaBucketPolicyViolations(metadata, policy)).toContain(
      expected,
    );
  });
});

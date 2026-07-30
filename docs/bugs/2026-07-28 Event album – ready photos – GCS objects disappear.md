---
type: bug
status: fixed-pending-verification
updated: 2026-07-28
---
# Event album – ready photos – GCS objects disappear

**Date:** 2026-07-28  
**Severity:** Critical — uploaded originals and variants were permanently lost while their production database records remained `READY`.  
**Surface:** Production API · private media storage · iOS event album

## Expected vs Actual

**Expected:** A photo marked `READY` retains its original, display, and
thumbnail objects until the verified seven-day event cleanup removes both
storage and server metadata.

**Actual:** One live production event retained five `READY` records after all
15 corresponding GCS objects had disappeared. Cached thumbnails still rendered
on one device, while an uncached tile loaded indefinitely and then showed no
image.

## Diagnostic evidence

- Production liveness and readiness remained healthy.
- Every affected database row was `READY`, but its original, display, and
  thumbnail object returned not found; listing all generations beneath the
  event prefix returned zero.
- A newly processed upload caused the storage reconciliation count to rise from
  zero to one event prefix, then return to zero within the next five-minute
  interval.
- The event was live and had no expiry tombstone, photo-deletion tombstone,
  cleanup job, deletion-queue job, or application cleanup log.
- The bucket had no lifecycle rules, versioning, soft delete, retention policy,
  Autoclass, or default hold. GCS automatic retention was not the cause.
- Production `MEDIA_BUCKET_NAME` was `photodome-dev`, the real-GCS development
  bucket documented for validation and cleanup.
- GCS object Data Access audit logging was not enabled, so the identity and
  command that issued the historical delete cannot be recovered. Exact caller:
  `TBD`.

## Root cause

Production and development did not have separate storage cleanup domains.
Production wrote durable media into `photodome-dev`; any development/manual
cleanup with access to that bucket could remove production objects without
touching the production database or its observable deletion queues.

GCS did not spontaneously expire the objects. It honored a deletion outside
PhotoDome's recorded production cleanup path. The missing audit trail prevents
attributing that request more precisely.

## Fix

- Provisioned `photodome-prod-younger7` as the dedicated production media
  bucket in project `younger7`, location `US`.
- Enforced uniform bucket-level access and public-access prevention; confirmed
  no public principal, versioning, soft delete, retention, lifecycle rule, or
  default hold.
- Verified the production service credential can write, issue a V4 signed read,
  deny anonymous access, and permanently remove an isolated verification
  object.
- Reconfigured and recreated the production API against the dedicated bucket;
  both health probes passed.
- Created the production-only
  `photodome-media-prod@younger7.iam.gserviceaccount.com` identity with
  bucket-scoped production access. It receives access denied from the
  development bucket, and the development identity no longer has a production
  bucket role.
- Added a fail-closed production configuration check that rejects media-bucket
  names marked `dev` or `development`.
- Added structured startup bucket-validation and single-photo deletion logs so
  application-owned storage actions are attributable.
- Confirmed all 30 exact old-bucket/new-bucket object checks for the five stale
  records were absent, confirmed they had no selections or deletion tombstones,
  and deleted exactly those five rows in one guarded database transaction.
  Their media bytes are unrecoverable because versioning and soft delete are
  deliberately disabled for the seven-day permanent-deletion promise.

## Verification

- Two fresh device uploads reached `READY` in the dedicated production bucket.
- Their two originals, two displays, and two thumbnails remained present for
  more than 17 minutes—over three reconciliation intervals—while the
  development bucket stayed empty.
- Production remained ready after the code deployment, credential isolation,
  stale-row cleanup, and final container recreation.
- Fresh-thumbnail rendering after cache eviction or on a second device remains
  physical-device verification.

## Related

- [[Media Upload and Retention]]
- [[GCS Development Bucket Validation]]
- [[Deployment & Release]]
- [[M2 Direct Upload and Live Album]]

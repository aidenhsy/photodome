---
type: reference
status: verified
updated: 2026-07-25
---
# GCS Development Bucket Validation

PhotoDome's real Google Cloud Storage development path is verified against:

- project: `younger7`;
- bucket: `photodome-dev`;
- location: `US`.

This clears the real-GCS development gate that remained after M2. It is not a
production bucket and must never be configured as production
`MEDIA_BUCKET_NAME`. Production uses the separately validated private bucket
`photodome-prod-younger7` in project `younger7`, location `US`, through the
separate `photodome-media-prod@younger7.iam.gserviceaccount.com` identity.

## Verified bucket controls

The fail-closed NestJS startup validator and Google Cloud control plane confirmed:

- uniform bucket-level access is enabled;
- public access prevention is enforced;
- no public IAM principal is present;
- object versioning is disabled;
- soft-delete retention is zero/disabled;
- no bucket retention policy blocks permanent deletion; and
- no default event-based hold is enabled.

These controls are required because PhotoDome must permanently remove originals, variants, and metadata seven days after an event ends. A soft-delete, versioning, retention, or hold policy could make an apparently deleted object remain recoverable and would therefore fail startup.

## Verified media lifecycle

Run:

```bash
cd photodome-api
npm run gcs:verify
```

The command uses the configured NestJS storage gateway and a new random event/photo prefix. It:

1. runs the same startup bucket-policy validator used by the API;
2. creates a GCS resumable upload session;
3. uploads a generated JPEG directly to GCS;
4. verifies byte count, content type, and SHA-256 by reading the stored object;
5. preserves the uploaded master and generates metadata-free display and thumbnail variants through Sharp;
6. verifies exactly three JPEG objects with `private, no-store`;
7. confirms anonymous raw object URLs are denied;
8. confirms V4-signed reads succeed for all three objects;
9. creates an additional abandoned object beneath the random event prefix;
10. uses the production event-prefix cleanup gateway to list and delete every generation beneath that prefix; and
11. lists all generations beneath the prefix again and requires zero remaining.

The post-M6 2026-07-25 verification completed successfully, deleted four object generations, and reported zero remaining.

## Safety properties

- The command refuses to run when `GCS_API_ENDPOINT` is set, preventing an emulator test from being mistaken for real GCS validation.
- Object keys are generated from random server UUIDs under the same `events/<event>/photos/<photo>` structure used by the application.
- Cleanup targets only the newly generated random event prefix. The command disables background workers and never deletes a bucket, user-selected event, or broad unresolved path.
- Credentials are loaded through Google Application Default Credentials and are never printed or written to the repository or vault.
- The bucket is private and intended only for event media. It is separate from foodapp media.
- The bucket is a development cleanup domain. Development verification and
  cleanup may delete its random prefixes, so no production record may reference
  an object in this bucket.
- Storage IAM is isolated in both directions: the production identity cannot
  list this development bucket, and the development identity has no role on the
  production bucket.

## Remaining storage work

- Repeat the shipped [[M6 Expiry Security and Scale]] shortened-TTL cleanup rehearsal in the production-like staging environment and on signed physical devices.

## Related

- [[Media Upload and Retention]]
- [[M2 Direct Upload and Live Album]]
- [[Architecture and Implementation Plan v0]]
- [[M6 Expiry Security and Scale]]

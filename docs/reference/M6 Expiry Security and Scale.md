---
type: reference
status: shipped
updated: 2026-07-25
---
# M6 Expiry Security and Scale

M6 is complete locally in this repository. PhotoDome now makes the seven-day retention promise authoritative: an event becomes inaccessible at its immutable `expiresAt`, every GCS generation under its event prefix is deleted and verified absent, and only then is its server metadata permanently purged.

## Shipped expiry contract

Ending an event still sets `expiresAt = endedAt + 7 days`. M6 additionally schedules a deterministic delayed BullMQ cleanup job for that timestamp.

At expiry, the worker:

1. transactionally marks the event `EXPIRING`, marks its non-removed photos `EXPIRED`, and creates or refreshes an independent cleanup tombstone;
2. rejects event access, reservations, upload completion publication, review, and downloads;
3. emits `event.expired` and disconnects the authenticated Socket.IO event room;
4. lists and deletes every GCS generation under `events/<eventId>/`, including originals, derived variants, and abandoned objects not represented by a photo row;
5. lists the prefix again across all generations and requires it to be empty; and
6. only after successful verification deletes the event and its cascaded members, photos, selections, transfer records, capabilities, Live Activity tokens, and cleanup tombstone.

The tombstone is independent of the event row and retains the event ID, exact prefix, attempt count, latest attempt time, and last error. A failed storage deletion or non-empty verification therefore leaves enough state to retry; database keys are not discarded early. BullMQ retries cleanup up to 12 times with exponential backoff.

A photo-processing completion that races expiry cannot publish `READY`. The repository marks the photo expired, the worker removes any generated objects, and no ready-photo realtime event is emitted.

## Reconciliation and orphan cleanup

Reconciliation runs at worker bootstrap and through a repeatable BullMQ scheduler. Its interval is configured with `CLEANUP_RECONCILIATION_INTERVAL_SECONDS` and defaults to 300 seconds.

Each pass combines:

- database events already `EXPIRING` or past `expiresAt`;
- retained cleanup tombstones from incomplete attempts; and
- UUID-shaped `events/<eventId>/` GCS prefixes that no longer have an event row.

An orphan prefix receives its own cleanup tombstone before a deterministic cleanup job is enqueued. Cleanup and reconciliation are idempotent, so a process restart, duplicate job, partial delete, or transient GCS failure converges on the same empty-prefix and metadata-purged result.

## iPhone expiry behavior

The authenticated realtime client listens for `event.expired`. On receipt, the app:

- removes the event capability from synchronizable Keychain;
- cancels that event's background upload and download tasks;
- deletes pending prepared uploads and downloaded local files;
- removes persisted resumable-session and signed-read state; and
- removes the event from the local UI.

Launch recovery now refreshes every restored event against the API before presenting it. An authoritative unauthorized or unavailable response performs the same local purge, while a generic offline/network failure preserves the recovered event until connectivity returns.

## Metrics and operations

Prometheus-format process and expiry metrics are exposed at `GET /v1/internal/metrics`. The route is excluded from the public OpenAPI contract. It returns 404 when `METRICS_BEARER_TOKEN` is not configured and otherwise requires that bearer token, compared in constant time.

M6 records:

- cleanup attempts by outcome;
- objects and bytes deleted;
- cleanup duration;
- prefix-verification failures;
- orphan prefixes discovered;
- reconciliation outcomes; and
- unique overdue cleanup count and oldest overdue age.

Cleanup logs contain stable IDs, attempt, duration, counts, and outcome. They do not contain capabilities, join/transfer tokens, ActivityKit tokens, resumable-session URIs, signed URLs, cookies, authorization headers, or installation IDs.

External metrics scraping, alert routing, dashboards, and production retention SLOs remain M7/deployment work.

## Bucket and security hardening

The startup validator fails closed if the media bucket has public IAM, Object Versioning, soft delete, a blocking retention policy, a default event-based hold, missing uniform bucket-level access, or unenforced Public Access Prevention. Unit fixtures cover both the safe policy and every rejected condition.

The shared Pino redaction list covers sensitive values at the request, response, top-level, and nested-operation shapes used by the application. A serialization test writes representative secrets through Pino and proves none appear in output. The production dependency audit (`npm audit --omit=dev`) reports zero known vulnerabilities as of 2026-07-25.

## V1 scale result

`npm run scale:verify` uses only the isolated `photodome_test` database. It creates exactly 100 members, 2,000 ready photos, and 1,000 private selection rows, proves that member 101 and photo 2,001 are rejected, measures 25 iterations, then purges its event.

| Local measurement | p95/result | M6 engineering budget |
|---|---:|---:|
| Event snapshot | 2.03 ms | 250 ms |
| Album page | 2.96 ms | 500 ms |
| Review page | 43.80 ms | 750 ms |
| Download manifest page | 92.81 ms | 500 ms |
| Cascaded event purge | 31.64 ms | 5,000 ms |

These are repeatable local database-level engineering gates, not production latency SLOs. Production topology, concurrency/load shape, network latency, and alert thresholds remain TBD.

## Verification completed on 2026-07-25

Backend:

- Prettier, ESLint, NestJS production compilation, and 17 unit tests passed.
- Ten PostgreSQL/Redis/GCS-backed E2E tests passed across health, accountless events, media, curation, and expiry.
- The shortened-TTL expiry E2E test creates host and guest state, processes media, ends the event, creates selections and transfer state, adds an abandoned object, proves access rejection at expiry, waits for delayed cleanup, and requires zero GCS generations and zero event metadata.
- A first-attempt GCS failure test proves the tombstone survives; its retry then verifies storage and finalizes metadata.
- The real `photodome-dev` verification deleted four object generations from an isolated random event prefix and confirmed zero remained.
- The full 100-member/2,000-photo scale command passed the budgets recorded above.

iOS:

- OpenAPI was re-exported and the Swift client/project regenerated without adding the internal metrics route.
- Swift formatting, Swift lint, app/widget compilation, and the signed iPhone simulator suite passed under Swift 6.
- The standard scheme reports 10 passed and five intentionally skipped live-API integration tests.

## Release validation still required

- Repeat the expiry rehearsal and offline/reconnect behavior with at least two signed physical iPhones.
- Provision and validate the production GCS bucket, workload identity, API host, PostgreSQL, Redis, and deployment process.
- Connect the protected metrics endpoint to production scraping, dashboards, cleanup-lag alerts, and incident routing.
- Complete the accessibility, privacy copy, crash reporting, TestFlight, and real-device work in M7.

## Related

- [[Architecture and Implementation Plan v0]]
- [[Media Upload and Retention]]
- [[GCS Development Bucket Validation]]
- [[M4 Host Lifecycle and Moderation]]
- [[M5 Personal Curation and Download]]

---
type: reference
status: shipped
updated: 2026-07-28
---
# M2 Direct Upload and Live Album

M2 is complete locally in this repository. An accountless guest can import a photo from the iPhone photo picker, upload it directly to private object storage through a resumable session, and have it appear in the host's live album after server verification and processing. Camera capture and Lock Screen entry remain M3 work.

## Shipped user flow

1. An attendee selects up to 20 images at a time from the system photo picker.
2. The app prepares a full-resolution JPEG master. A compatible JPEG import with no capture override remains byte-for-byte unchanged, including its orientation, capture time, GPS, and other embedded metadata. A supported still that requires conversion receives one quality-0.95 full-resolution JPEG encode with its source metadata copied.
3. NestJS admits the photo in a serializable transaction and returns a GCS resumable session URI. The API never proxies the media bytes.
4. The iPhone writes the prepared JPEG to protected Application Support storage and starts a background `URLSession` file upload. UI dismissal, backgrounding, and connectivity waits do not discard the queued intent.
5. After GCS accepts the bytes, the app calls the generated completion operation. The API independently verifies existence, byte count, content type, and SHA-256.
6. BullMQ invokes Sharp to read—but never overwrite—the stored master and create metadata-free 2048 px display and 512 px thumbnail JPEG variants.
7. The photo becomes `READY`; Socket.IO publishes `event.photo_ready` to authenticated event clients.
8. The receiving client refreshes album metadata and displays the photo through a short-lived private read URL.
9. Failed transfers stay visible with a Retry action. Retry asks NestJS for a fresh resumable session for the existing admitted reservation and restarts the protected local file transfer.

As soon as selected or captured bytes are available, the local photo appears at
the newest end of the album grid. Its overlaid loader uses one stable
**Uploading** label while preparation, transfer, verification, and processing
continue automatically; failure keeps the photo in place with a tap-to-retry
affordance. Every preparing, queued, and ready thumbnail uses the same exact
square layout and center crop, so source orientation cannot resize the grid.
A stable client UUID hands the cell from the
pre-reservation preview to the durable queue. The canonical server `photoId`
then replaces it without duplication when the photo becomes ready. Once the
photo appears in the server album, the app deletes its local prepared file and
removes the completed queue item.

## Admission and lifecycle behavior

- The reservation transaction admits only an active event member and enforces the 2,000-photo event envelope.
- The current M2 media input is JPEG after client normalization, with a maximum prepared size of 20 MB and maximum declared dimension of 20,000 px.
- A host upload restriction blocks new reservations. It does not invalidate a reservation already admitted, and an admitted owner can renew its upload session.
- `ENDED` events can still accept new reservations while uploads remain unrestricted. `EXPIRING` or actually expired events reject media access.
- M2 stores `admitted_before_restriction` explicitly for later M4 lifecycle/concurrency work.
- Seven-day deletion was not part of M2; the cleanup coordinator and destructive expiry proof are now shipped in [[M6 Expiry Security and Scale]].

## Backend implementation

### Persistent model

The M2 Prisma migration adds `Photo` with:

- `RESERVED | PROCESSING | READY | FAILED | REMOVED | EXPIRED` state;
- event and contributor-member relations;
- deterministic private object keys for original, display, and thumbnail;
- content type, byte count, SHA-256, dimensions, capture time, and orientation;
- reservation, upload, ready, and failure fields;
- event/state/ready-time and contributor/state indexes.

Reservations run at serializable isolation. Object keys are generated from server UUIDs and contain no attendee-provided filenames or text.

### API operations

| Method | Path | OpenAPI operation |
|---|---|---|
| `GET` | `/v1/events/:eventId/photos` | `listEventPhotos` |
| `POST` | `/v1/events/:eventId/photos/reservations` | `reservePhotoUpload` |
| `POST` | `/v1/events/:eventId/photos/:photoId/upload-session` | `renewPhotoUploadSession` |
| `POST` | `/v1/events/:eventId/photos/:photoId/complete` | `completePhotoUpload` |

All four routes require the event bearer capability. Album listing returns only `READY` rows, cursor pagination, and independently issued display/thumbnail URLs.

### Storage and processing

- Local development uses `fsouza/fake-gcs-server` 1.54.0 with a dedicated `photodome-media-dev` bucket.
- Real environments require `GCS_PROJECT_ID` and `MEDIA_BUCKET_NAME`; `GCS_API_ENDPOINT` is only for a local compatible endpoint.
- Production read URLs use GCS V4 signing and default to a five-minute TTL. Emulator reads use its private local download endpoint.
- Sharp leaves the uploaded master bytes unchanged, then writes a metadata-free 2048 px quality-0.82 display variant and 512 px quality-0.75 thumbnail.
- All written objects use `private, no-store`.
- Real-bucket startup fails closed unless uniform bucket-level access and public access prevention are enabled and public IAM, object versioning, soft delete, retention policy, and default event holds are absent. These checks preserve the later permanent-deletion guarantee.
- The real GCS development target is project `younger7`, private bucket
  `photodome-dev`, region `US`. Production uses the separate private bucket
  `photodome-prod-younger7` in the same project and region through the separate
  `photodome-media-prod@younger7.iam.gserviceaccount.com` identity. The
  production identity cannot access the development bucket, and the development
  identity has no production-bucket role. Both buckets enforce uniform
  bucket-level access and public-access prevention with versioning, soft delete,
  retention, lifecycle rules, and default holds disabled. Production startup
  rejects a media-bucket name marked dev/development; see
  [[GCS Development Bucket Validation]] and [[Deployment & Release]].

## iOS implementation

- `ImagePreprocessor` creates the full-resolution upload master, SHA-256, dimensions, orientation, and approved capture timestamp. Compatible JPEG imports remain byte-for-byte unchanged with their embedded metadata; inputs requiring conversion receive only one full-resolution high-quality encode.
- `BackgroundUploadManager` owns a stable background-session identifier and reconnects to OS tasks after relaunch.
- `UploadQueueStore` persists reservation/session/file/task state in an atomically written, protected file. The resumable session URI is treated as a bearer secret and is not logged or sent to analytics.
- Event capabilities remain in iCloud Keychain and are loaded only when the queue calls completion or session renewal; they are not copied into the queue file.
- `APIClient` consumes regenerated OpenAPI media operations and maps them into app-owned domain types.
- `EventRealtimeClient` connects with the event capability in the Socket.IO authentication payload and keeps library logging disabled.
- `EventAlbumView` provides prominent full-width camera/import actions, an
  optimistic local-photo grid with one **Uploading** presentation and
  actionable retry, empty state, and an exact square layout that constrains
  every center-cropped preparing, queued, and ready cell with a four-point gap.
- Album photos now use the protected, downsampled Kingfisher pipeline described
  in [[Local-First Event Media Cache]]. A per-event metadata snapshot renders
  before the network, cursor pages load near the grid tail, and stable
  event/photo/variant keys reuse pixels across rotating five-minute signed
  URLs.
- Imported and queued local masters are previewed through bounded ImageIO
  thumbnails instead of decoding full-resolution upload bytes into the grid.

## Local operation

```bash
cd photodome-api
npm install
docker compose up -d
npm run prisma:migrate:deploy
npm run start
```

Local ports are PostgreSQL `5434`, Redis `6381`, GCS emulator `4443`, and API `3663`.

```bash
cd photodome-ios
Scripts/regenerate-api.sh
open PhotoDome.xcodeproj
```

The generated `openapi.json`, Swift client, Xcode project, and Swift package resolution are repository artifacts. Resumable session URIs, prepared photos, credentials, database volumes, Redis data, emulator uploads, and build products are not.

## Verification completed through 2026-07-26

Backend:

- Prettier, ESLint, production compilation, and dependency audit passed with zero production vulnerabilities.
- Four unit tests passed.
- Five PostgreSQL/Redis/GCS-backed E2E tests passed.
- The media E2E test proves guest reservation, direct resumable upload, server checksum verification, BullMQ processing, byte-for-byte preservation of the stored master, thumbnail dimensions/metadata removal, authenticated Socket.IO `READY`, and host album visibility.

iOS:

- Swift formatting/lint and simulator build passed.
- Ten unit/integration tests passed.
- Media tests prove compatible JPEG import bytes and embedded GPS survive unchanged, a camera master receives its shutter-time GPS and capture date, a GPS-free import receives no current location, and the protected upload queue round-trips its session/task state.
- The live integration scheme passed against the local NestJS/Redis/PostgreSQL/GCS stack. It proves that two independent accountless clients create/join and that a guest's direct photo upload becomes visible through the host client's generated album API.
- The Build 3 upload-presentation regression passes with all active internal
  states mapped to **Uploading** and a portrait optimistic fixture constrained
  to the same square as ready media. The complete iOS scheme passes 74 tests
  (69 passed, five expected opt-in live-API skips), including all 17 UI tests,
  and the signed generic Release build succeeds.

## Device and production validation still required

The local milestone is shipped, but these release gates remain:

- interrupt/background/terminate/relaunch testing with a large transfer on a physical iPhone and weak network;
- retry after a genuinely expired GCS resumable session on a physical iPhone;
- simultaneous Socket.IO delivery and connection pooling across at least two physical iPhones;
- M4 restriction-race and post-end upload concurrency tests;
- The shortened-TTL destructive cleanup proof is now complete in [[M6 Expiry Security and Scale]].

## Related

- [[Architecture and Implementation Plan v0]]
- [[Media Upload and Retention]]
- [[M1 Accountless Event Spine]]
- [[GCS Development Bucket Validation]]

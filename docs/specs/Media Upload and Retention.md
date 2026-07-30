---
type: spec
status: planned
updated: 2026-07-26
---
# Media Upload and Retention

Design spec for PhotoDome's iPhone-to-Google-Cloud-Storage photo pipeline, post-event uploads, and permanent seven-day cleanup. It applies the useful parts of foodapp's image stack while closing the durability, privacy, and orphaned-object gaps found in the 2026-07-25 audit. Product behavior comes from [[Product Discovery Brief]].

Created 2026-07-25 after confirming that uploads may continue after the host ends an event, in-progress uploads survive a host upload restriction, and all server media must be permanently deleted seven days after ending.

Amended and implemented locally 2026-07-26 by [[2026-07-26 Media Fidelity
Decision]]: the private downloadable master retains embedded GPS and other
source metadata, while optimized display/thumbnail variants keep the album
fast. PhotoDome camera capture additionally requires foreground
precise-location authorization and embeds the shutter-time coordinate.

## Overview & Context

**The pitch** — Upload directly and durably from iPhone to a private GCS bucket, show optimized variants in the live album, and hard-delete every event object when its seven-day post-event window expires.

**Why this needs its own design** — PhotoDome is a media product, not an app that happens to contain a few photos. A birthday can create hundreds or thousands of simultaneous uploads, users expect an in-progress photo not to disappear when the host closes contribution, and short-lived media must not become a permanent storage bill.

**Confirmed lifecycle**

1. Host and guests participate without accounts.
2. While contribution is open, a participant may reserve and start an upload.
3. Host ending the live event does not close uploads.
4. Host may later restrict new uploads.
5. An upload reserved before restriction is allowed to finish.
6. Exactly seven days after the host ends the event, PhotoDome expires access and permanently deletes the event's GCS objects and server metadata.

## Foodapp Audit

Audited 2026-07-25 against the local source and live `gs://foodapp-dev` configuration.

### Reusable pieces

| Foodapp component | Finding | PhotoDome use |
|---|---|---|
| `ImageCompressor.swift` | Uses ImageIO thumbnail decoding instead of expanding a full 12 MP image; fixes orientation, re-encodes JPEG, strips EXIF/GPS, and has 1600 px / 0.78 plus 512 px presets. | Reuse the downsample/encode technique for display and thumbnail variants. |
| `IObjectStorageGateway` + `GcsStorageGateway` | Storage sits behind a port with upload/download/delete operations. Delete uses `ignoreNotFound`, which is idempotent. | Keep the port, but add direct-upload session creation, prefix/batch deletion, private signed reads, and cleanup verification. |
| `ReviewUploadManager` | Lets the composer dismiss while parallel uploads continue and presents progress. | Reuse the UX principle, but back it with a persistent queue and background `URLSession`; foodapp's in-memory `Task` does not survive termination. |
| OpenAPI client | NestJS generates the contract consumed by a typed Swift client. | Use for event, reservation, completion, and cleanup-state APIs. |

### Do not copy as-is

- Foodapp's upload endpoint buffers a multipart file in the NestJS process and calls `file.save(..., resumable: false)`. PhotoDome should not proxy event photo bytes through the API.
- Foodapp's main upload manager is an in-memory Swift `Task`. It can continue after a sheet dismisses, but it is not a durable OS background transfer queue.
- Foodapp's single-photo delete removes the DB row before GCS deletion. If the storage delete fails, the object is orphaned and its key has already been discarded.
- Foodapp's account purge treats GCS deletion as best-effort and only logs failures. PhotoDome's seven-day promise requires retry, reconciliation, and observable failure state.
- Foodapp's dev bucket serves public object URLs. Event photos require a private bucket and time-limited access.
- Foodapp's 1600 px / 0.78 upload is appropriate for a social feed but is not sufficient as the only downloadable memory copy unless the product explicitly chooses reduced-quality downloads.

### Live foodapp bucket finding

`gs://foodapp-dev` was observed with:

- Region `ASIA-NORTHEAST1`, Standard storage, uniform bucket-level access.
- Soft delete disabled.
- Object Versioning enabled with no lifecycle configuration visible.
- Approximately 6.73 GiB of live objects versus 7.28 GiB across all generations.
- 62,497 live objects versus 65,521 listed generations—about 3,024 noncurrent generations.
- `allUsers` currently has both `roles/storage.admin` and `roles/storage.objectAdmin`. This is a critical configuration error; it is much broader than public read.

PhotoDome must use a separate bucket and must not inherit these IAM/versioning settings.

## Goals & Non-Goals

### Goals

1. Keep the API out of the photo-byte data path.
2. Preserve upload intent across UI dismissal, backgrounding, connectivity changes, and host upload restriction.
3. Let every reserved upload finish even if the host closes new contribution afterward.
4. Make private preview/download access expire with event access.
5. Make GCS cleanup idempotent, retryable, observable, and reconciled.
6. Ensure no event object remains billable after permanent cleanup completes.
7. Preserve a full-resolution downloadable master and its embedded source metadata, including GPS when present, without repeated lossy master encoding.
8. Require foreground precise-location authorization for PhotoDome camera capture and embed the authorized capture coordinate without stamping import-time location onto library photos.

### Non-goals

- Permanent cloud albums.
- Public bucket delivery.
- Copying foodapp's restaurant/image categorization or AI features.
- Assuming a database cascade also deletes object-storage bytes.
- Depending on a user's successful download before the seven-day deadline.

## Proposed Solution & UX

### Accountless host recovery

Use capability-based identity with no registration screens:

1. On first launch, PhotoDome creates a random installation identity and stores it in Keychain.
2. Creating an event returns a high-entropy, event-scoped **host capability** distinct from the public join code.
3. Store the host capability in an iCloud-synchronizable Keychain item. On a replacement iPhone using the same Apple ID with iCloud Keychain enabled, host control returns automatically—no PhotoDome account, email, password, or Sign in with Apple.
4. Offer **Transfer host controls** inside the event settings. It displays a short-lived, one-time QR/deep link that another iPhone can scan; successful transfer rotates the host capability.
5. Never put host authority into the public join QR/code. A join capability can contribute/view; a host capability can additionally end the live event and restrict uploads.
6. If the original phone is lost and iCloud Keychain was unavailable, host recovery is intentionally unavailable rather than weakening event security. The event still expires automatically after seven days.

This is the least-barrier safe design: capability recovery remains invisible and the device-transfer path only appears when needed. A participant display name is collected separately for in-session recognition, but it is not an account or authorization credential.

### Upload state machine

```text
LOCAL_PENDING
  -> RESERVING
  -> RESERVED
  -> UPLOADING
  -> UPLOADED
  -> PROCESSING
  -> READY

Retryable: RESERVING / UPLOADING / PROCESSING -> RETRY_PENDING
Terminal: FAILED | EXPIRED
```

- Before sending bytes, the iOS app asks NestJS to reserve `photoId` and object keys.
- The reservation records `eventId`, anonymous contributor, creation time, content type/hash/size, and whether it was admitted before the host's upload cutoff.
- Closing uploads blocks new reservations. It does not revoke already-issued reservations or transfer sessions.
- Reservations may be reissued a transfer session after transient failure until event expiry, even if the host has since closed new uploads.
- At the seven-day deadline, unfinished reservations become `EXPIRED`; any object that appears later is deleted by completion handling and reconciliation.

### Direct GCS upload

1. NestJS validates the scoped event capability and creates the reservation.
2. NestJS initiates a GCS resumable upload and returns its HTTPS session URI to the iPhone. Treat the URI as a bearer secret.
3. iOS writes the full-resolution prepared master to a local file and uploads from that file with a background `URLSession`, persisting reservation/session metadata locally. Preparation preserves embedded metadata and encoded source pixels where supported; if normalization is required, it performs at most one high-quality full-resolution encode. A PhotoDome camera master embeds the foreground precise-location coordinate captured with the shutter; a library import retains only the source's own GPS.
4. On completion, iOS calls the typed completion endpoint; the server verifies object existence, size, content type, checksum, reservation, and unexpired event.
5. BullMQ generates display/thumbnail variants and marks the photo `READY`.
6. Socket.IO announces the ready photo; the live album never renders a half-uploaded object.

GCS recommends resumable uploads for unreliable/slow transfers, and a resumable session URI can continue without further GCS authentication. The URI must therefore be short-lived in local logs, never sent to analytics, and only transmitted over HTTPS.

### Optimistic album presentation

The album may render a local preview while its object is not yet server-readable; this is presentation state, not publication of a half-uploaded object.

1. As soon as the picker or camera returns image bytes, iOS inserts that local image at the newest end of the album grid with a loader.
2. One client UUID identifies the preview through local preparation, server reservation, and the durable background-upload queue.
3. The loader and badge show one stable user-facing **Uploading** state from
   local preparation through server processing. The implementation retains its
   detailed durable states for recovery and observability, but does not present
   them as separate attendee steps. Do not create a detached linear progress
   row for each photo.
4. A failed admitted transfer keeps its local image and shows tap-to-retry. Retry renews the existing server reservation.
5. When the ready-photo page contains the queue item's canonical `photoId`, the remote row replaces the local row. The merge must deduplicate Socket.IO refresh and queue-cleanup races.
6. The protected local master remains available to restore pending thumbnails after UI dismissal or app relaunch and is deleted only after the matching ready photo is acknowledged.

The local preview never grants another participant early access, changes server state, or weakens the rule that the shared album API returns only verified `READY` photos.

### Image variants

Recommended storage set:

```text
events/<eventId>/photos/<photoId>/original.<ext>
events/<eventId>/photos/<photoId>/display.jpg
events/<eventId>/photos/<photoId>/thumb.jpg
```

- **Original/master:** full-resolution download copy for the seven-day window. Preserve source visual content, orientation, capture time, GPS, and other embedded source metadata. Preserve the encoded source where supported; otherwise normalize once at high quality. Variant processing must not re-encode and overwrite this master.
- **Display:** ImageIO/Sharp downsample, proposed 2048 px long edge and JPEG quality around 0.82 for full-screen album viewing.
- **Thumbnail:** proposed 512 px long edge and JPEG quality around 0.75 for grids/swipe prefetch.
- Display and thumbnail variants may omit metadata; authorized downloads of the master carry the retained metadata.
- Reject files over 20 MB before creating a transfer session.
- Enforce v1 event limits of 100 attendees and 2,000 photos.
- Reads use short-lived signed URLs or authenticated proxy metadata—not public GCS URLs.
- A signed URL is a temporary credential rather than a durable media identifier. Album clients must retain the server-provided expiry, refresh near expiry when returning to the foreground, and request a fresh album page when a currently displayed URL fails. Recovery must compare the failed URL with current page state and coalesce concurrent refreshes so many lazy-grid failures cannot create a request storm.

### Event expiry and permanent deletion

At host ending:

1. Set immutable `endedAt`.
2. Set `expiresAt = endedAt + 7 days`.
3. Enqueue a delayed BullMQ cleanup job keyed by event ID.

At `expiresAt`:

1. Atomically mark the event `EXPIRING`; reject reads, downloads, new reservations, retries, and completion publication.
2. Keep database media keys/tombstones while deleting. Do not delete the DB rows first.
3. Delete every object under `events/<eventId>/`, including original, display, thumbnail, and abandoned completed-upload objects.
4. Verify that listing the prefix returns zero live objects.
5. Permanently delete media rows, selection rows, transfer sessions, capabilities, and all event metadata, then mark/remove the cleanup tombstone.
6. If any step fails, retry with exponential backoff and retain the tombstone/keys.
7. Run a scheduled reconciliation worker that finds every expired event not fully cleaned and every GCS `events/<eventId>/` prefix without a live event.
8. Emit cleanup counts, bytes removed, duration, retry count, and oldest overdue cleanup metrics; alert when an expired event remains unclean.

### Bucket configuration

Use a dedicated PhotoDome media bucket:

- Standard regional storage near the API/initial users.
- Uniform bucket-level access.
- Public Access Prevention: **enforced**.
- No `allUsers` or `allAuthenticatedUsers` IAM bindings.
- Soft delete: **disabled**, because short-lived media would otherwise remain billable after deletion.
- Object Versioning: **disabled**, because noncurrent generations would violate permanent deletion and continue consuming storage.
- No retention policy or hold that blocks seven-day deletion.
- A least-privilege service account limited to the PhotoDome bucket.
- GCS Object Lifecycle Management as defense-in-depth, not the primary scheduler. If Custom-Time is used, set it from `expiresAt`; keep the BullMQ cleanup and reconciliation path because lifecycle execution is asynchronous.
- Infrastructure verification must fail deployment if public access, soft delete, versioning, or a blocking retention policy is enabled.

Google documents that soft-deleted objects continue to incur storage charges and explicitly warns that soft delete can substantially increase cost for short-lived data. New buckets enable seven-day soft delete by default, so PhotoDome must turn it off deliberately.

## Acceptance Criteria

- **Given** an accountless host who has completed the one-field first-launch display-name prompt, **when** they create an event, **then** host control is stored without registration, email, password, or Sign in with Apple.
- **Given** the same Apple ID with synchronizable Keychain enabled, **when** the host installs PhotoDome on another iPhone, **then** their unexpired host capabilities become available automatically.
- **Given** a reserved upload, **when** the host closes uploads, **then** that upload may finish and retry; only new reservations are rejected.
- **Given** a photo transfer, **when** the app is backgrounded, **then** the OS-backed transfer continues and progress restores when the app returns.
- **Given** an upload completes, **when** PhotoDome publishes it, **then** GCS size/checksum and the server reservation agree.
- **Given** a supported source with embedded GPS or other metadata, **when** an authorized member downloads its master, **then** that metadata survives the import/upload/download round trip.
- **Given** foreground precise-location authorization, **when** PhotoDome captures a camera photo, **then** the contributed master embeds the capture coordinate.
- **Given** a library photo without GPS, **when** it is imported, **then** PhotoDome does not attach the device's current/import-time coordinate.
- **Given** a supported source whose encoded representation can be retained, **when** PhotoDome prepares and processes the master, **then** the server does not perform another lossy master encode.
- **Given** a participant views an album, **when** they request an image, **then** access is private and time-limited.
- **Given** event expiry, **when** cleanup runs, **then** the GCS event prefix is empty before its media keys are discarded from the database.
- **Given** a transient GCS deletion failure, **when** cleanup retries or reconciliation runs, **then** it can complete idempotently without losing the object keys.
- **Given** a participant selects or captures a photo, **when** local image bytes become available, **then** the photo appears immediately in the newest album-grid position with its pending state overlaid.
- **Given** that optimistic photo is portrait or landscape, **when** any active
  upload stage renders it, **then** it stays center-cropped inside the same
  square grid frame and shows only **Uploading** until ready.
- **Given** an optimistic photo advances from preparation to the durable queue and then to `READY`, **when** each identity handoff occurs, **then** exactly one visual cell represents that photo.
- **Given** cleanup success, **when** GCS is queried across all generations, **then** no object for the event remains.
- **Given** deployment configuration, **when** the bucket has public IAM, soft delete, versioning, or deletion-blocking retention enabled, **then** infrastructure validation fails.

## Alternatives Considered

| Option | Benefits | Costs / risks | Decision |
|---|---|---|---|
| Required Sign in with Apple | Straightforward cross-device recovery | Adds a barrier before a spontaneous event | Rejected for v1 |
| Local-only host token | Invisible and simple | Lost phone means lost host control; no transfer | Insufficient alone |
| iCloud-synchronizable Keychain + transfer capability | Zero-form normal path and secure recovery/transfer | Requires careful capability rotation; recovery unavailable if both iCloud and old device are gone | Recommended |
| Proxy multipart bytes through NestJS like foodapp | Familiar and easy OpenAPI endpoint | API memory/bandwidth bottleneck; weaker background/resume behavior | Rejected |
| Direct resumable upload | API stays lightweight; reliable on weak event networks | More state-machine work; session URI is sensitive | Recommended |
| Delete DB then GCS like foodapp's single-photo flow | Simple | A failed object delete becomes an untraceable orphan | Rejected |
| GCS lifecycle only | Low application code | Lifecycle is asynchronous and does not prove per-event cleanup | Defense-in-depth only |
| Keep GCS soft delete/versioning | Recovery from accidental deletes | Continued cost and conflicts with permanent seven-day deletion | Rejected for media bucket |

## Technical & Cross-Cutting Concerns

- **Privacy:** signed reads, scoped capability checks, a private bucket, contributor disclosure, and strict prevention of metadata leakage into logs/traces/analytics are mandatory. Authorized master downloads intentionally retain embedded GPS and other source metadata.
- **Integrity:** use a stable SHA-256 application hash and verify GCS checksums/size at completion.
- **Idempotency:** photo ID fixes the object prefix; reservation, completion, variant generation, and cleanup are repeatable.
- **Concurrency:** host restriction is an admission cutoff. A reservation committed before the cutoff is valid; a reservation attempted afterward is rejected.
- **Cost:** track live bytes by event, derived/original ratio, egress, incomplete reservations, noncurrent/soft-deleted bytes (expected zero), and overdue cleanup bytes.
- **Security:** host/recovery/session capabilities are bearer secrets. Store server-side hashes where possible and redact them from logs.
- **Operations:** use separate dev/staging/prod buckets; never reuse `foodapp-dev`.

## Milestones & Open Questions

### Milestones

1. Capability identity and event reservation schema.
2. Private PhotoDome GCS bucket with policy validation.
3. Direct resumable upload vertical slice.
4. Persistent iOS background upload queue and progress UI.
5. Variant generation and signed album delivery.
6. Host close-upload cutoff with grandfathered reservations.
7. Seven-day cleanup worker, retries, reconciliation, metrics, and destructive integration test.

### Approved limits and policies

- Keep a full-resolution, metadata-preserving master for download during the seven-day window.
- Preserve capture date, orientation, GPS, and other embedded source metadata; do not repeatedly re-encode the master.
- Require foreground precise-location authorization for PhotoDome camera capture; denied, restricted, or reduced-accuracy authorization blocks capture and routes to Settings.
- Maximum 100 attendees, 2,000 photos, and 20 MB per original in v1.
- If iCloud Keychain is unavailable and the original host device is lost, do not weaken the join credential to recover host control.
- Permanently delete all event media and server metadata at day seven.

## Related

- [[Product Discovery Brief]]
- [[2026-07-25 Product Walkthrough]]
- [[2026-07-26 Media Fidelity Decision]]
- [[Architecture and Implementation Plan v0]]
- the foodapp "Food Journal Photo Upload Stack" reference (external note, not included in this repo)
- [[Design Spec Rules]]

## External references

- [GCS resumable uploads](https://docs.cloud.google.com/storage/docs/resumable-uploads)
- [GCS Object Lifecycle Management](https://docs.cloud.google.com/storage/docs/lifecycle)
- [GCS soft delete](https://docs.cloud.google.com/storage/docs/soft-delete)
- [Disable GCS soft delete](https://docs.cloud.google.com/storage/docs/disable-soft-delete)

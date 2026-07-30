---
type: reference
status: shipped
updated: 2026-07-28
---
# Local-First Event Media Cache

PhotoDome's album and review surfaces use one Kingfisher-backed media path so
previously viewed private photos appear from protected device storage while the
app refreshes server metadata in the background. This implementation follows
foodapp's single-wrapper, downsampled-image pattern and extends it for
PhotoDome's rotating signed URLs and seven-day event lifecycle. It shipped in
PhotoDome PR #13 as `3f523c2`.

## At a glance

| Concern | Shipped behavior |
|---|---|
| Remote image library | Kingfisher 8.10.0 through `CachedEventImage` |
| Cache identity | Event ID + photo ID + thumbnail/display variant; never the rotating signed URL |
| Memory | 96 MB, 180 decoded images, ten-minute maximum |
| Disk | 512 MB, seven-day maximum, shortened to the event expiry |
| Grid decode size | 512 px longest side |
| Review decode size | 1,280 px longest side |
| Album metadata | Protected, atomically written per-event JSON snapshot |
| Pagination | First page immediately; next pages load near the grid tail |
| Prefetch | Initial and near-visible thumbnail windows; next four review cards |
| Privacy removal | Per-photo eviction on moderation and per-event eviction on expiry/revocation/forget |

## How it works

`CachedEventImage` is the only SwiftUI remote-event-image wrapper. It keeps
loads alive when a lazy grid cell leaves the viewport, downsamples before
display, and reads thumbnails synchronously from disk to avoid placeholder
flashes. `AsyncImage` is not used for event media.

GCS read signatures rotate about every five minutes, but the underlying display
and thumbnail objects do not. The cache key therefore uses the stable event,
photo, and variant identity. A refreshed credential can retrieve the same
cached bitmap without creating another disk entry. An expired credential is
never used for network access: Kingfisher may serve an existing protected cache
entry, while a miss triggers the existing coalesced metadata refresh.

Each opened album stores its loaded `AlbumPhoto` pages, next cursor, and ready
count under protected Application Support. On the next open, that snapshot
renders before upload-manager setup or any API response. The authenticated API
then refreshes every page needed to replace the restored range. Home follows
the same local-first principle by publishing Keychain event snapshots before
background queue setup and server reconciliation.

The grid prefetches the initial 18 thumbnails and advances an 18-photo window as
the person scrolls. It requests another server page within 12 cells of the
loaded tail. Review prefetches four 1,280 px display variants. Local import and
queued-upload cells use ImageIO thumbnails rather than decoding full camera
masters into memory.

Review decisions update the card and local counts immediately. The server write
continues while the next prefetched card is visible; a failed write restores the
previous card and counts and presents the normal error.

## Retention and failure behavior

- Cache entries cannot outlive the known event expiry. The normal ten-minute
  memory and seven-day disk limits are shortened when expiry is sooner.
- Removing a photo evicts both processed variants and updates the album
  snapshot.
- Event expiry, access revocation, or forgetting an event deletes its snapshot
  and all indexed variants.
- If the snapshot is missing or unreadable during event deletion, PhotoDome
  clears the complete event-media cache rather than risk retaining an orphaned
  private image.
- A missing or corrupt optional snapshot never blocks authenticated network
  loading.
- The server remains authoritative; local snapshots are warm presentation data,
  not a second source of product state.

## Key files

- `PhotoDome/Services/EventImagePipeline.swift`
- `PhotoDome/Services/AlbumSnapshotStore.swift`
- `PhotoDome/Services/LocalImageThumbnailer.swift`
- `PhotoDome/Features/Events/EventAlbumViewModel.swift`
- `PhotoDome/Features/Events/PhotoReviewViewModel.swift`

## Verification completed on 2026-07-28

- Strict Swift formatting and lint pass.
- The signed simulator suite reports 53 tests: 48 passed, five intentionally
  skipped opt-in API integration tests, and zero failures.
- Regression coverage proves stable keys across signed-URL rotation, protected
  snapshot round trips and deletion, bounded ImageIO thumbnail dimensions,
  cursor-page merging/persistence, expired credential handling, immediate
  review-card advancement, and rollback after a failed decision.
- The signed generic iOS Release build succeeds with the app and Live Activity.

Physical-iPhone validation remains required for first-open versus warm-cache
scrolling, relaunch while offline, memory pressure, low storage, and known event
expiry while the album is open.

## Related

- [[M2 Direct Upload and Live Album]]
- [[M5 Personal Curation and Download]]
- [[Media Upload and Retention]]
- [[Release 0.1.0 (Build 2)]]

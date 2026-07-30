---
type: bug
status: fixed-pending-verification
updated: 2026-07-27
---
# Event album – scroll or return after signed URL expiry – photos show gray placeholders

**Date:** 2026-07-27  
**Severity:** High — the album can look as though photos were lost even though every private media object remains intact.  
**Surface:** iOS · Event detail → photo grid  
**Files:** `EventAlbumView.swift`, `EventAlbumViewModel.swift`, `PhotoModels.swift`

## Environment

- User-reported device: iPhone model `TBD`
- User-reported OS: iOS version `TBD`
- User-reported build: PhotoDome build `TBD`
- Backend: production
- Reproducible: deterministic in the view-model regression with five-minute signed URLs; physical-device reproduction frequency `TBD`

## Expected vs Actual

**Expected:** Every ready photo remains visible for the event's availability window. The app transparently replaces short-lived private-media URLs as they expire.

**Actual:** Photos that loaded while their signed URLs were valid remain visible, while photos first requested after URL expiry become gray tiles with a generic photo icon. The mixed grid makes intact photos look missing.

## Reproduction Steps

Starting state: an album has more ready photos than fit in the first visible grid rows, and the API returns five-minute thumbnail URLs.

1. Open the event album and leave it open long enough for the signed URLs to expire.
2. Keep the initially visible rows loaded.
3. Scroll to rows that have not loaded yet, or background and later resume the app.
4. Observe: previously loaded thumbnails may remain visible from cache, but newly requested thumbnails show gray placeholders.

## Visual evidence (textual)

The reported three-column album showed real thumbnails in its first two rows and generic photo icons in later rows. Ownership badges and the duplicate-download confirmation remained present, proving the photo records still existed even though the image requests failed.

## Diagnostic evidence

- The album API exposes `urlsExpireAt`, and production signed URLs are valid for 300 seconds.
- `EventAlbumViewModel` fetched the album only during bootstrap and realtime photo changes. It did not inspect `urlsExpireAt` when the app became active.
- `AlbumThumbnail` used `AsyncImage`; its failure phase rendered a permanent placeholder and did not ask for a fresh signed URL.
- Read-only storage verification confirmed the affected ready media still had its original, display, and thumbnail objects. No object keys or production records were copied into this vault.

Before implementation, the new regression did not compile because the album had no URL-refresh policy or injectable photo-listing boundary:

```text
error: cannot find type 'AlbumPhotoListing' in scope
** TEST FAILED **
```

## Root cause

The app treated a time-limited authorization URL as though it were a durable media identifier:

```swift
let thumbnailURL: URL
let urlsExpireAt: String
```

The expiry timestamp was stored but never used by the live album. `AsyncImage` could cache thumbnails loaded while a URL was valid, explaining why the top rows survived, but lazy rows first requested after five minutes received an expired GCS signature. Their failure state rendered only the placeholder.

Failure sequence:

1. The album API returns ready-photo records and signed display/thumbnail URLs.
2. The URLs expire after five minutes.
3. Visible rows load before expiry and may remain cached.
4. The view model keeps the original response indefinitely.
5. A lazy row appears after expiry and requests its stale URL.
6. GCS rejects the expired signature.
7. The thumbnail shows a generic placeholder without refreshing the album.

## What I ruled out

- **Retention cleanup:** the event remained inside its seven-day window, and private media objects still existed. **Rejected.**
- **Variant processing failure:** affected album rows were already `READY`, and their display/thumbnail variants existed. **Rejected.**
- **Photo-record loss:** ownership badges and download behavior remained attached to the tiles. **Rejected.**
- **Signed-URL lifecycle omission:** the app retained five-minute URLs across a much longer view lifetime and never acted on `urlsExpireAt`. **Confirmed cause.**

## Fix

- Added `AlbumMediaURLRefreshPolicy`, which parses the earliest photo expiry and requests fresh URLs when the app becomes active within 30 seconds of expiry.
- A thumbnail load failure now reports its exact failed URL to the album model. If that URL is still current, the model refreshes the album once.
- Old failure callbacks are ignored after fresh URLs replace the page, preventing many blank cells from causing duplicate API calls.
- A 15-second recovery cooldown prevents a transient network outage from creating a signed-URL refresh loop.
- Concurrent album refreshes are coalesced through the existing loading state.

Regression coverage proves:

1. the earliest expiry controls foreground refresh;
2. a near-expiry foreground transition replaces old thumbnail URLs; and
3. one current-URL failure refreshes once while later stale callbacks do not refetch.

```text
AlbumMediaURLRefreshTests
Executed 3 tests, with 0 failures
** TEST SUCCEEDED **
```

Project lint and strict Swift formatting passed. The Release simulator
configuration built successfully. The non-flaky unit run executed 31 tests
with zero failures and five expected opt-in API integration skips; the full UI
suite executed 9 tests with zero failures.

Physical-device verification with an album left open beyond five minutes remains required before changing this report to `fixed`.

## Pattern lesson

A signed URL is a short-lived credential, not the media's identity. Any client screen that can outlive the URL must preserve a stable media ID, retain the server-provided expiry, refresh on foreground when near expiry, and recover once when a current URL fails. Failure recovery must compare the failed URL with current state so a grid of stale callbacks cannot create a request storm.

## Related

- [[Media Upload and Retention]]
- [[M5 Personal Curation and Download]]
- [[iOS Coding Rules]]
- [[Bug Report Rules]]

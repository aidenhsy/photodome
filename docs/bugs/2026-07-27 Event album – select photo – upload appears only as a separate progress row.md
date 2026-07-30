---
type: bug
status: fixed-pending-verification
updated: 2026-07-27
---
# Event album – select photo – upload appears only as a separate progress row

**Date:** 2026-07-27  
**Severity:** Medium — uploads complete, but a core contribution action feels unresponsive and users cannot visually connect transfer state to the photo they selected.  
**Surface:** iOS · Event detail → Camera or Add → photo upload  
**Files:** `photodome-ios/PhotoDome/Features/Events/EventAlbumView.swift`, `EventAlbumViewModel.swift`, `BackgroundUploadManager.swift`, `PhotoModels.swift`

## Environment

- User-reported device: iPhone model `TBD`
- User-reported OS: iOS version `TBD`
- User-reported build: PhotoDome build `TBD`
- Regression environment: iPhone 17 Pro simulator, iOS 26.5, Debug
- Backend: presentation defect is client-side; reservation/upload environment does not change the original layout
- Reproducible: every time before the fix

## Expected vs Actual

**Expected:** As soon as the app obtains the selected or captured image bytes, the actual photo appears at the newest end of the album grid. A loader and short state badge sit on that photo until the canonical server photo replaces it; a failed transfer stays on the photo with tap-to-retry.

**Actual:** The grid contains only server-side `READY` photos. Each pending upload appears instead as a separate text row with its own linear progress bar, so the chosen photo is absent from the album until reservation, transfer, verification, and processing all finish.

## Reproduction Steps

Starting state: join an event whose uploads are open and open its album.

1. Tap **Add** and choose a photo, or take one with **Camera**.
2. Dismiss the picker/camera and look at the newest end of the photo grid.
3. Wait while the upload moves through uploading, verifying, and processing.
4. Observe: the selected photo is missing from the grid; only a detached progress row represents it until the server publishes it as `READY`.

## Visual evidence (textual)

The original album placed an upload-status card between the Camera/Add controls and the three-column grid. Each queued item was a horizontal row containing a state icon, text, and linear progress bar. The selected image itself did not appear in the grid during any pending state.

The requested replacement keeps the three-column grid stable: the local photo appears in the first cell with a dim overlay, centered spinner, and `Preparing`, `Uploading`, `Verifying`, or `Processing` badge. Failure replaces the spinner with a retry symbol and `Tap to retry`.

## Diagnostic evidence

The old view rendered two unrelated collections:

```swift
uploadStatus

ForEach(model.photos) { photo in
    AlbumGridCell(photoID: photo.id) {
        handlePhotoTap(photo)
    } label: {
        AlbumThumbnail(url: photo.thumbnailURL)
    }
}
```

`model.photos` comes from `GET /events/:eventId/photos`, which intentionally returns only `READY` rows. Meanwhile, `BackgroundUploadManager` already retained the prepared local file and every transfer state, but the view used those queue items only to build the separate progress panel.

Foodapp's chat path demonstrated the missing precedent: it inserts a temporary image message with local bytes immediately, keeps a stable temporary identity during upload, and swaps it for the canonical server message while deduplicating realtime races.

## Root cause

The persistence model and the presentation model were split at the wrong boundary. PhotoDome had durable local upload intent, but the album grid treated the server's ready-photo page as its sole visual source of truth.

Failure sequence:

1. The picker or camera returns image data.
2. The client preprocesses it and asks the API for a reservation.
3. Only after reservation does `BackgroundUploadManager` append an item containing the protected local file.
4. `EventAlbumView` renders that item outside the grid as a progress row.
5. The grid waits for upload, completion verification, variant processing, Socket.IO delivery, and an album refresh.
6. The user sees no visual continuity between the photo they chose and the ready photo that eventually appears.

The confirmed cause is the absence of an optimistic grid representation and a stable UI identity spanning pre-reservation, queued, and canonical states.

## What I ruled out

- **Hypothesis 1 — slow image picker:** the picker returns the selected bytes successfully; the missing feedback continues through all later queue states. **Rejected.**
- **Hypothesis 2 — no local image available:** `ImagePreprocessor` writes a protected local master, and `UploadQueueItem.localFileURL` remains valid until the ready photo is acknowledged. **Rejected.**
- **Hypothesis 3 — server or Socket.IO failure:** successful uploads eventually appear, and the same gap occurs with a healthy local stack. Server latency lengthens the gap but does not require a blank grid cell. **Rejected.**
- **Hypothesis 4 — optimistic representation omitted:** the grid iterated only `model.photos`, while every pending item was deliberately routed to `uploadStatus`. **Confirmed cause.**

## Fix

- Insert an in-memory preview as soon as image bytes are available, before preprocessing and reservation.
- Carry one UUID from that preparing preview into the persisted `UploadQueueItem`, so the queue cell replaces—not duplicates—the temporary cell.
- Render the queue's protected local file directly in the grid with an indeterminate loader and compact state badge.
- Keep failed queue items in place with a tap-to-retry affordance.
- Remove the detached per-photo linear progress panel.
- Hide a queue cell as soon as a server `READY` row with the same `photoID` arrives, preventing a Socket.IO/queue-acknowledgement race from showing two copies.
- Put optimistic cells before ready cells because the album API sorts newest ready photos first.

The identity handoff is explicit:

```swift
let uploadID = UUID()
preparingUploads.append(
    PreparingAlbumPhoto(id: uploadID, image: image)
)

_ = await model.addPhoto(
    data: data,
    uploadID: uploadID
)
```

`AlbumUploadGridPolicyTests` verifies newest-first queue ordering, event isolation, preparing-to-queue deduplication, and queue-to-ready deduplication. Swift formatting and strict lint passed. The four focused tests pass on iPhone 17 Pro / iOS 26.5. The non-flaky scheme run executed 35 unit tests with zero failures and five expected opt-in integration skips, and all 9 UI tests passed. The Release simulator build also succeeded. Physical-device visual, background/foreground, and retry testing remain required before changing this report to `fixed`.

Merged in PhotoDome PR #5 as `0741f81` on 2026-07-27.

## Pattern lesson

A durable media queue is not automatically an optimistic UI. For any user-created media, insert the local preview at intent time, give it a stable client identity, and carry that identity into the durable queue. Reconcile again by the canonical server media ID, because realtime delivery may race queue cleanup. Render pending and failure state on the media itself, preserve retry, and test both identity handoffs so optimistic content never flashes, disappears, or duplicates.

## Related

- [[M2 Direct Upload and Live Album]]
- [[Media Upload and Retention]]
- [[iOS Coding Rules]]
- [[Bug Report Rules]]

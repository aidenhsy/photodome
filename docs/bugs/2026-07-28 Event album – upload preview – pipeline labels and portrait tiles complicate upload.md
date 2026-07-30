---
type: bug
status: fixed-pending-verification
updated: 2026-07-28
---
# Event album – upload preview – pipeline labels and portrait tiles complicate upload

**Date:** 2026-07-28  
**Severity:** Medium — uploads succeed, but internal stage labels make a simple contribution feel slow and portrait previews break the album grid.  
**Surface:** iOS · Event detail → Camera or Photos → pending upload tile  
**File:** `photodome-ios/PhotoDome/Features/Events/EventAlbumView.swift`

## Environment

- User-reported device: physical iPhone model `TBD`
- User-reported OS: iOS version `TBD`
- User-reported build: TestFlight `0.1.0 (2)`
- Regression environment: iPhone 17 Pro simulator, iOS 26.5, Debug
- Backend: the durable upload pipeline is working; this defect is in its iOS presentation

## Expected vs Actual

**Expected:** Selecting or capturing a photo immediately creates one square, center-cropped grid tile with one stable **Uploading** state. Verification and variant generation happen safely in the background without becoming extra user-facing steps. Failure remains explicit and retryable.

**Actual:** The same photo visibly advances through **Preparing**, **Uploading**, **Verifying**, and **Processing**. Portrait optimistic previews can retain their source aspect in layout, making pending cells taller than ready square thumbnails and allowing the image treatment to escape the intended frame.

## Reproduction Steps

Starting state: open an event whose uploads are allowed.

1. Tap **Camera** or **Photos** and contribute a portrait image.
2. Return to the album.
3. Watch the pending tile until the server publishes the ready photo.
4. Observe multiple technical stage names on one user action.
5. Compare the pending portrait tile with a ready tile in the same row.

## Root cause

The durable upload state machine was exposed directly as product copy. That state machine is required for background transfer, integrity verification, variant generation, and retry, but its internal boundaries do not represent separate decisions or actions for the attendee.

The pending cells also allowed a resizable aspect-fill image to participate in the cell's ideal layout before visual clipping. Clipping hid overflow pixels but did not guarantee a square layout proposal for the composed optimistic tile.

## Fix

- Map preparing, uploading, verifying, and processing to one user-facing **Uploading** presentation and one VoiceOver label.
- Keep only the actionable failure presentation: **Tap to retry**.
- Put preparing, queued, and ready thumbnails through one square layout container.
- Give the image an exact square proposal and render it as an overlay on the frame, so portrait/landscape intrinsic dimensions cannot resize the grid cell.
- Preserve center-crop, the local optimistic preview, automatic background continuation, durable retry, and the backend's verification/processing safeguards.
- Add unit coverage proving every active internal state maps to **Uploading** and UI coverage proving a portrait optimistic tile renders in a square frame with the simplified status.

## Verification

- Swift format and strict lint pass.
- Six focused upload-grid unit tests pass.
- The focused simulator UI regression passes on iPhone 17 Pro / iOS 26.5.
- The portrait regression fixture was visually inspected: the image is center-cropped inside a square tile and the only visible active label is **Uploading**.
- The complete iOS scheme passes 74 tests: 69 passed and five expected opt-in live-API tests skipped. This includes 57 unit tests and all 17 UI/accessibility tests.
- The signed generic iOS Release build succeeds.
- [PR #18](https://github.com/aidenhsy/photodome/pull/18) squash-merged into Build 3 as `b807556`. This is an iOS-only change; no production API deployment is required.
- Physical-device confirmation remains before this report moves to `fixed`.

## Pattern lesson

Reliability stages belong in the system, not automatically in the interface. Show one state for one uninterrupted user intent unless the person must make a decision. For aspect-fill media, constrain layout with an exact frame before clipping; pixel clipping alone is not a grid guarantee.

## Related

- [[M2 Direct Upload and Live Album]]
- [[Media Upload and Retention]]
- [[Product Discovery Brief]]
- [[Release 0.1.0 (Build 3)]]

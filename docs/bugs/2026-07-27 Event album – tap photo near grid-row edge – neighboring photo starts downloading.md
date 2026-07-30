---
type: bug
status: fixed-pending-verification
updated: 2026-07-27
---
# Event album – tap photo near grid-row edge – neighboring photo starts downloading

**Date:** 2026-07-27  
**Severity:** Medium — the visible download target can resolve to the wrong photo, but the user can retry away from the row edge and no server data is lost.  
**Surface:** iOS · Event detail → photo grid → single-photo download  
**File:** `photodome-ios/PhotoDome/Features/Events/EventAlbumView.swift`

## Environment

- User-reported device: iPhone model `TBD`
- User-reported OS: iOS version `TBD`
- User-reported build: PhotoDome build `TBD`
- Backend: not involved in target resolution; URL/environment `TBD`
- Reproducible: user report frequency `TBD`; every time in the iPhone 17 Pro / iOS 26.5 simulator regression harness when tapping at 98% of the upper cell's height

## Expected vs Actual

**Expected:** Tapping any visible point inside a photo tile starts or confirms a download for that exact photo.

**Actual:** A tap near the boundary between grid rows can start the download for the neighboring photo below instead.

## Reproduction Steps

Starting state: an event album contains at least two ready photos in adjacent grid rows, with thumbnails rendered using `scaledToFill`.

1. Open the event detail.
2. Locate two photo tiles directly above and below each other.
3. Tap near the bottom edge of the upper photo.
4. Observe: the lower photo's download state changes instead of the upper photo's.

Automated reproduction: launch the Debug app with `PhotoDomeUITestAlbumGridHitTargets` and run `AccessibilityUITests.testAlbumGridEdgeTapsSelectTheVisiblePhoto`.

## Visual evidence (textual)

The album is a three-column square-photo grid. The tap appears visually inside the upper tile, but the download arrow/progress state changes on the tile in the next row. No layout overlap is visible because the thumbnail pixels are clipped to their squares.

## Diagnostic evidence

The regression harness uses the production grid-cell button with deliberately mismatched portrait/landscape `scaledToFill` content. Before the fix, tapping 98% down the visible upper button invoked the lower button:

```text
Tap "albumPhoto.top" Button[0.50, 0.98]
AccessibilityUITests.swift:141: error:
XCTAssertEqual failed: ("Tapped bottom") is not equal to ("Tapped top")
Executed 1 test, with 1 failure
** TEST FAILED **
```

The same failure shape already existed in foodapp's `PickerGridCell`: a scaled thumbnail's interaction region crossed the visible square and a neighboring row handled the tap. Foodapp commit `f213b3403a8ea693094ffea7307a50a4867e43e8` added an explicit rectangular content shape.

## Root cause

The album button clipped the thumbnail's pixels but did not define the button label's interaction shape:

```swift
Button {
    handlePhotoTap(photo)
} label: {
    ZStack {
        AlbumThumbnail(url: photo.thumbnailURL)
        // badges and download indicator
    }
}
.buttonStyle(.plain)
```

`AlbumThumbnail` used `AsyncImage(...).scaledToFill()` and then `.clipped()`. In SwiftUI, visual clipping does not reliably constrain hit testing to the visible bounds. The scaled child retained an interaction region outside the square cell.

Failure sequence:

1. `scaledToFill` lays out a thumbnail large enough to fill the square.
2. Clipping hides pixels beyond the square but does not replace the composed label's hit-test shape.
3. Adjacent lazy-grid cells therefore have overlapping interactive regions near a row boundary.
4. SwiftUI resolves the tap to the neighboring button.
5. That button's closure correctly passes its own `AlbumPhoto`, so the download manager correctly downloads the wrong target it was given.

## What I ruled out

- **Hypothesis 1 — unstable `ForEach` identity:** `ForEach(model.photos)` keys each cell by the stable `AlbumPhoto.id`, and the failure occurs without inserting, removing, or reordering photos. **Rejected.**
- **Hypothesis 2 — download-manifest ID mismatch:** `handlePhotoTap` passes the selected `photo.id`, and `PhotoDownloadManager.start(photoID:)` requests a manifest for that exact ID. The wrong cell action fires before networking begins. **Rejected.**
- **Hypothesis 3 — asynchronous thumbnail reuse:** the deterministic harness reproduces the failure with local SF Symbols and no network/image cache. **Rejected.**
- **Hypothesis 4 — clipped `scaledToFill` hit-region overflow:** the failing edge coordinate invokes the adjacent button; adding a rectangular `contentShape` to the shared label makes both edge taps resolve correctly with no download-layer changes. **Confirmed cause.**

## Fix

All album tiles now go through one `AlbumGridCell`. The shared cell explicitly constrains the button label's interaction shape to its visible rectangular layout bounds:

```swift
Button(action: action) {
    label()
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
```

The Debug-only regression surface renders vertically overflowing thumbnail content through that same component. Its UI test taps the bottom 2% of the upper tile and top 2% of the lower tile, then verifies the matching photo ID handled each tap.

Verification on iPhone 17 Pro simulator / iOS 26.5:

```text
testAlbumGridEdgeTapsSelectTheVisiblePhoto passed
Executed 1 test, with 0 failures
** TEST SUCCEEDED **
```

Project lint and strict formatting checks passed, and the app built successfully
for the Release simulator configuration with the Debug-only harness excluded.
The complete local scheme run passed 32 tests, skipped 5 opt-in API integration
tests, and failed only the pre-existing locale-sensitive
`EventTimestampFormatterTests.testFormatsEventTimeInTheRequestedLocalTimeZone`;
all 9 UI tests, including the grid-edge regression, passed.

Physical-device verification against a real event album remains required before changing this report to `fixed`.

## Pattern lesson

Do not assume `.clipped()` or `.clipShape(...)` makes a `scaledToFill` image's tap region match its visible grid cell. Visual clipping and hit testing are separate SwiftUI concerns. Put `.contentShape(Rectangle())` on the button label after its layout is established, route all repeated cells through that shared component, and regression-test taps near every shared edge. This applies to photo pickers, album grids, feeds, and any dense grid containing aspect-fill media.

## Related

- [[M5 Personal Curation and Download]]
- [[Product Discovery Brief]]
- [[iOS Coding Rules]]
- [[Bug Report Rules]]

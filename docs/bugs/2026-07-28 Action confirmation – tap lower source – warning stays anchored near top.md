---
type: bug
status: fixed-pending-verification
updated: 2026-07-28
---
# Action confirmation – tap lower source – warning stays anchored near top

**Date:** 2026-07-28  
**Severity:** Medium — the correct action is confirmed, but a warning detached from the tapped item makes the interface feel inaccurate and can obscure unrelated content.  
**Surface:** iOS · Event album, host controls, and attendee management  
**Files:** `photodome-ios/PhotoDome/Features/Events/EventAlbumView.swift`, `photodome-ios/PhotoDome/Features/Events/EventDetailView.swift`

## Environment

- User-reported device: iPhone model `TBD`
- User-reported OS: iOS version `TBD`
- User-reported build: PhotoDome build `TBD`
- Backend: not involved
- Reproducible: user report frequency `TBD`; confirmed structurally in all six action-specific SwiftUI confirmation sites

## Expected vs Actual

**Expected:** A warning for a tapped photo, attendee row, or host-control button presents from that action's visible source. SwiftUI may place the adaptive confirmation above or below the source to fit the screen, but it should remain spatially associated with the control that opened it.

**Actual:** The confirmation used one fixed source near the top/root of the screen. Scrolling farther down and tapping another item changed the warning's content but not its presentation source.

## Reproduction Steps

Starting state: open an event containing enough photos to scroll the album.

1. Tap a saved photo near the top and dismiss **Download this photo again?**
2. Scroll several rows down.
3. Tap another saved photo.
4. Observe: the second confirmation presents from the same root-screen location rather than the lower photo.

The same ownership problem affected:

- **Delete this photo?**
- **Rotate the join code?**
- **End this event?**
- **Restrict new uploads?**
- **Remove attendee?**

## Visual evidence

The user supplied a screenshot of **Download this photo again?** detached from the selected lower album tile. The confirmation appears over a fixed region of the album instead of using the tapped tile as its adaptive presentation source.

## Diagnostic evidence

Before the fix, both album confirmations were attached after the album's root `VStack`, all three host confirmations were attached after the event's root `ScrollView`, and attendee removal was attached after the attendee screen's root container:

```swift
ScrollView {
    // many controls
}
.confirmationDialog(
    "End this event?",
    isPresented: $showsEndConfirmation
) {
    // actions
}
```

The trigger button changed Boolean or selected-item state, but it did not own the presentation modifier. SwiftUI therefore used the root container as the popover/action source on every invocation.

## Root cause

SwiftUI presentation modifiers belong to the view they modify. A `confirmationDialog` attached to a screen or scrolling container is sourced from that container, not from whichever descendant happened to mutate its binding.

The original implementation centralized six confirmations at screen boundaries. That looked convenient for state handling, but discarded the identity and geometry of the initiating control. In repeated photo and attendee rows, a single non-ID-scoped optional selection then drove the root-owned presentation.

System placement is adaptive: iOS can place a confirmation above or below its source when space is constrained, and compact presentations are not a pixel-positioning API. The app can and must provide the correct source view; it should not attempt to hard-code popup coordinates.

## What I ruled out

- **Hypothesis 1 — the wrong photo is selected:** the earlier overlapping-grid-hit-region defect was already fixed, and this report occurs even when the warning title/action references the correct photo. **Rejected.**
- **Hypothesis 2 — stale scroll geometry:** no custom geometry, anchor preference, or scroll offset participates in the confirmation. **Rejected.**
- **Hypothesis 3 — download-manager behavior:** the warning appears before the download action is confirmed, so networking and PhotoKit are not involved. **Rejected.**
- **Hypothesis 4 — every alert should follow the tapped control:** app-level error alerts describe screen-wide failures and should remain centered/root-owned. Only action-specific confirmations require a control source. **Rejected as a blanket rule.**
- **Hypothesis 5 — presentation ownership is wrong:** every affected modifier was attached to a root/container instead of its trigger. Moving the modifiers to the corresponding photo cell, row action, or host button gives SwiftUI the correct source geometry. **Confirmed cause.**

## Fix

Each action-specific confirmation is now attached directly to the visible control that opens it:

- album delete and repeat-download confirmations → the exact `AlbumGridCell`;
- rotate-code confirmation → **Rotate join code**;
- end-event confirmation → **End event**;
- restrict-upload confirmation → **Restrict new uploads**; and
- attendee removal confirmation → the exact guest row's **Remove** button.

Repeated photo and attendee controls use ID-scoped bindings so only the selected cell's modifier is presented:

```swift
Binding(
    get: { photoPendingRedownload?.id == photo.id },
    set: { isPresented in
        if !isPresented, photoPendingRedownload?.id == photo.id {
            photoPendingRedownload = nil
        }
    }
)
```

General failure `.alert` modifiers remain at the screen boundary because they are intentionally screen-modal and have no single initiating control.

The implementation shipped to `main` through PhotoDome PR #10 as
`7e03bd2`.

A Debug attendee surface now contains enough rows to scroll. Its UI regression opens the warning from the lowest guest row, verifies that the lower guest's confirmation is shown, and checks that the adaptive presentation remains near that lower source rather than reverting to the top of the screen.

Verification on iPhone 17 simulator / iOS 26.5:

```text
testLowerAttendeeWarningUsesTheTappedRowAsItsSource passed
Executed 1 test, with 0 failures
** TEST SUCCEEDED **
```

Strict Swift formatting, SwiftLint, and app-icon validation pass. The signed
unit suite executed 43 tests with five expected opt-in API integration skips
and zero failures. The Release simulator build also succeeds with the
Debug-only regression surface excluded.

Physical-device verification remains required before changing this report to
`fixed`.

## Pattern lesson

Attach `confirmationDialog`, `popover`, and other source-relative presentations to the exact button, cell, or row that initiated them. Changing state in a descendant does not make a root-owned modifier inherit that descendant's geometry. In repeated content, scope the presentation binding by stable item ID so precisely one source owns the active presentation.

Keep app-level error alerts on the screen boundary. Do not replace adaptive system placement with guessed popup coordinates; provide the correct source and let iOS fit the presentation above or below it.

## Related

- [[M4 Host Lifecycle and Moderation]]
- [[M5 Personal Curation and Download]]
- [[Product Discovery Brief]]
- [[iOS Coding Rules]]
- [[Bug Report Rules]]

---
type: bug
status: fixed-pending-verification
updated: 2026-07-28
---
# Event invite – tap Copy code – no confirmation appears

**Date:** 2026-07-28  
**Severity:** Low — the code reaches the pasteboard, but the silent action makes hosts unsure whether it worked and encourages repeated taps.  
**Surface:** iOS · Event detail → host invite card → Copy code  
**File:** `photodome-ios/PhotoDome/Features/Events/EventDetailView.swift`

## Environment

- User-reported device: iPhone model `TBD`
- User-reported OS: iOS version `TBD`
- User-reported build: PhotoDome build `TBD`
- Backend: not involved; copy is device-local
- Reproducible: every time in the previous implementation

## Expected vs Actual

**Expected:** Tapping **Copy code** copies the current join code and immediately confirms success visually and to VoiceOver.

**Actual:** The pasteboard changes silently. The button and screen show no acknowledgement.

## Reproduction Steps

Starting state: a host has opened an event with a current join code.

1. Find the **INVITE PEOPLE** card.
2. Tap **Copy code**.
3. Keep looking at the invite card.
4. Observe: no text, icon, toast, or accessibility announcement confirms that the code was copied.

## Visual evidence (textual)

Before and after the tap, the outlined button continues to read **Copy code** with no other visible state change.

## Diagnostic evidence

The old button performed only the pasteboard mutation:

```swift
Button("Copy code") {
    UIPasteboard.general.string = joinCode
}
```

It had no confirmation state, animation, toast/banner, or accessibility announcement. The focused UI regression now verifies the production control changes from **Copy code** to **Code copied**:

```text
testInviteOffersCopyWithVisibleConfirmationButNotShare passed
Executed 1 test, with 0 failures
** TEST SUCCEEDED **
```

## Root cause

The original implementation treated a successful `UIPasteboard` assignment as sufficient completion, but pasteboard writes have no automatic on-screen acknowledgement. SwiftUI therefore had no state change to render and assistive technology received no completion event.

Failure sequence:

1. The button writes `joinCode` to `UIPasteboard.general.string`.
2. No view state changes.
3. SwiftUI re-renders the same button label.
4. The host cannot distinguish success from a missed or failed tap.

## What I ruled out

- **Hypothesis 1 — the button action does not fire:** the closure directly assigns the current join code to the general pasteboard. **Rejected.**
- **Hypothesis 2 — the backend must acknowledge the copy:** copying is entirely local and does not require a request. **Rejected.**
- **Hypothesis 3 — iOS supplies automatic confirmation:** `UIPasteboard` writes do not add app UI or a success announcement. **Rejected.**
- **Hypothesis 4 — missing app-owned confirmation state:** the prior view contained no such state, and adding it produces the required visible transition. **Confirmed cause.**

## Fix

The invite card now uses one reusable `InviteCodeCopyButton`. A tap writes the code, changes the full-width control to a checked **Code copied** state for two seconds, and posts the same VoiceOver announcement. Repeated taps replace the dismissal task through SwiftUI's task identity, so an older timer cannot hide newer feedback:

```swift
UIPasteboard.general.string = joinCode
UIAccessibility.post(
    notification: .announcement,
    argument: "Code copied"
)
withAnimation {
    confirmationID = UUID()
}
```

The focused production-component UI regression passes, along with Swift formatting and lint. On the iPhone 17 Pro / iOS 26.5 simulator, the complete scheme passes 52 tests with 47 passed, 5 opt-in API integration tests skipped, and zero failures; the Release simulator build also succeeds. PR #8 was squash-merged to `main` as `f2f791b` on 2026-07-28. Physical TestFlight verification remains before this report moves to `fixed`.

## Pattern lesson

Every clipboard write is a user action with an invisible side effect. Pair it with immediate visible confirmation and an accessibility announcement, keep the feedback long enough to perceive, and cancel or replace stale dismissal work when the action repeats. Regression-test the actual production component rather than a mock button.

## Related

- [[2026-07-28 Event invite – tap Share invite – unfinished placeholder link is offered]]
- [[M1 Accountless Event Spine]]
- [[Product Discovery Brief]]
- [[iOS Coding Rules]]
- [[Bug Report Rules]]

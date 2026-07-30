---
type: bug
status: fixed-pending-verification
updated: 2026-07-28
---
# Event invite – tap Share invite – unfinished placeholder link is offered

**Date:** 2026-07-28  
**Severity:** Medium — the host is offered a sharing action whose URL cannot open PhotoDome for its recipient, but the QR and short code remain usable.  
**Surface:** iOS · Event detail → host invite card → Share invite  
**File:** `photodome-ios/PhotoDome/Features/Events/EventDetailView.swift`

## Environment

- User-reported device: iPhone model `TBD`
- User-reported OS: iOS version `TBD`
- User-reported build: PhotoDome build `TBD`
- Backend: not involved in constructing the shared URL
- Reproducible: every time; the compiled share action uses the placeholder `https://photodome.invalid` base

## Expected vs Actual

**Expected:** Until PhotoDome has a production invite domain and complete universal-link handoff, the host invite card offers only working invite actions: show the QR and copy the short code.

**Actual:** The card also offers **Share invite**, which passes an intentionally non-routable `photodome.invalid` URL to the iOS share sheet.

## Reproduction Steps

Starting state: a host has opened an event with a current join code.

1. Find the **INVITE PEOPLE** card.
2. Tap **Share invite**.
3. Send or inspect the shared link.
4. Observe: the payload uses the unfinished `photodome.invalid` host and cannot hand the recipient into PhotoDome.

## Visual evidence (textual)

Two equal-width actions appear beneath the QR and join code: **Copy code** and **Share invite**. The latter looks production-ready even though its shared link is still a placeholder.

## Diagnostic evidence

The share control exported `InvitePayload.url` directly:

```swift
ShareLink(item: invite.url) {
    Text("Share invite")
}
```

The payload's current base is intentionally non-production:

```swift
static let localInviteBaseURL = URL(
    string: "https://photodome.invalid"
)!
```

The focused UI regression now proves that the production copy control exists and no **Share invite** action is exposed:

```text
testInviteOffersCopyWithVisibleConfirmationButNotShare passed
Executed 1 test, with 0 failures
** TEST SUCCEEDED **
```

## Root cause

The invite card treated the app-internal placeholder payload as an externally shareable URL. `InvitePayload` is sufficient for generating and parsing the in-app QR path, but the `.invalid` domain deliberately has no DNS or universal-link configuration. `ShareLink` does not validate that product readiness; it faithfully exposes whatever URL it receives.

Failure sequence:

1. `hostInvite` creates `InvitePayload.join(code:)`.
2. `InvitePayload.url` builds a URL under `https://photodome.invalid`.
3. `ShareLink` presents that URL as a working host action.
4. A recipient cannot resolve the placeholder domain or hand it into PhotoDome.

## What I ruled out

- **Hypothesis 1 — the backend returns a bad link:** the backend returns a join code; the iOS domain model constructs the URL locally. **Rejected.**
- **Hypothesis 2 — the iOS share sheet is malfunctioning:** `ShareLink` receives and shares the exact placeholder URL supplied by the app. **Rejected.**
- **Hypothesis 3 — the QR and short-code invite are also unavailable:** the QR remains scannable by PhotoDome's scanner and manual code entry remains supported; only external link sharing lacks its production handoff. **Rejected.**
- **Hypothesis 4 — an unfinished URL was exposed as a completed action:** the hard-coded `.invalid` base and absent production universal-link configuration confirm that the action is premature. **Confirmed cause.**

## Fix

The public host invite card no longer renders `ShareLink`. It keeps the QR, visible short code, and full-width copy action. The share action can return only after a real invite domain, Associated Domains entitlement, Apple App Site Association file, and installed/not-installed handoff are implemented and verified together.

The focused UI regression launches the production copy component, asserts **Share invite** is absent, taps copy, and verifies its confirmation. Swift formatting and lint pass. On the iPhone 17 Pro / iOS 26.5 simulator, the complete scheme passes 52 tests with 47 passed, 5 opt-in API integration tests skipped, and zero failures; the Release simulator build also succeeds. PR #8 was squash-merged to `main` as `f2f791b` on 2026-07-28. Physical TestFlight verification remains before this report moves to `fixed`.

## Pattern lesson

Do not expose a platform share control merely because a payload can be serialized. First prove the recipient can resolve and open it across installed, not-installed, and expired/rotated cases. Placeholder `.invalid`, localhost, development, or internal-only URLs must remain behind debug tooling or have their share affordance hidden until the complete external handoff ships.

## Related

- [[2026-07-28 Event invite – tap Copy code – no confirmation appears]]
- [[M1 Accountless Event Spine]]
- [[Product Discovery Brief]]
- [[iOS Coding Rules]]
- [[Bug Report Rules]]

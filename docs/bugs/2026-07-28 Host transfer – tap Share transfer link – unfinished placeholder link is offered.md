---
type: bug
status: fixed-pending-verification
updated: 2026-07-28
---
# Host transfer – tap Share transfer link – unfinished placeholder link is offered

**Date:** 2026-07-28  
**Severity:** Medium — the host is offered a sharing action whose URL cannot open PhotoDome for its recipient; additionally the payload is a one-time host-transfer credential that the same screen instructs the host never to post publicly. The in-app transfer QR remains fully usable.  
**Surface:** iOS · Event detail → Transfer host sheet → Share transfer link  
**File:** `photodome-ios/PhotoDome/Features/Events/EventDetailView.swift`

## Environment

- Device: iPhone 17 Pro Max simulator
- OS: iOS 26.4
- Build: Debug build from `fix/streamline-ui-ux` against the local API
- Backend: not involved in constructing the shared URL
- Reproducible: every time; the compiled share action uses the placeholder `https://photodome.invalid` base

## Expected vs Actual

**Expected:** Until PhotoDome has a production invite domain and complete universal-link handoff, the Transfer host sheet offers only the working transfer action: the one-time QR scanned in person on the new host's iPhone.

**Actual:** The sheet also offers **Share transfer link**, which passes an intentionally non-routable `photodome.invalid` URL — carrying the live one-time transfer token — to the iOS share sheet.

## Reproduction Steps

Starting state: a host has opened an event and started a host transfer.

1. Open the **Transfer host** sheet.
2. Tap **Share transfer link**.
3. Send or inspect the shared link.
4. Observe: the payload uses the unfinished `photodome.invalid` host and cannot hand the recipient into PhotoDome.

## Root cause

Identical to [[2026-07-28 Event invite – tap Share invite – unfinished placeholder link is offered]]: `HostTransferView` exported `InvitePayload.url` through `ShareLink`, treating the app-internal placeholder payload as an externally shareable URL. The `.invalid` domain deliberately has no DNS or universal-link configuration; only PhotoDome's own QR scanner can parse the payload. PR #8 removed the equivalent action from the invite card but the Transfer host sheet was missed.

The transfer surface compounds the defect: the shared item is a short-lived, single-use host-authority credential, and the sheet's own copy says "Never post this QR publicly." Routing it through the share sheet contradicts the in-person scan model even before the dead domain is considered.

## Fix

`HostTransferView` no longer renders `ShareLink`; the sheet keeps the QR, the one-time/short-lived caption, and the warning copy. A DEBUG `HostTransferRegressionView` behind the `PhotoDomeUITestHostTransfer` launch argument backs the focused UI regression `testHostTransferOffersQRButNotShareLink`, which asserts the Transfer host sheet and QR exist and **Share transfer link** is absent.

Any future share affordance must follow the same gate as the invite card: real invite domain, Associated Domains entitlement, Apple App Site Association file, and verified installed/not-installed handoff — and for this surface, an explicit product decision that a transfer credential may travel over external channels at all.

On the iPhone 17 Pro Max / iOS 26.4 simulator, `testHostTransferOffersQRButNotShareLink` passes alongside the neighbouring invite, archive, and empty-home regressions, and the rebuilt Debug app shows the sheet with only the QR, caption, warning copy, and Done. PR #15 was squash-merged to `main` as `574f35d` on 2026-07-28 (the PR also carries the unrelated local dev port move to 3663). Physical TestFlight verification remains before this report moves to `fixed`.

## Related

- [[2026-07-28 Event invite – tap Share invite – unfinished placeholder link is offered]]
- [[M1 Accountless Event Spine]]
- [[Bug Report Rules]]

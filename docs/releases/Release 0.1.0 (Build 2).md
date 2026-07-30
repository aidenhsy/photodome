---
type: plan
status: superseded
updated: 2026-07-28
---
# Release 0.1.0 (Build 2)

> [!warning] ⚪ SUPERSEDED 2026-07-28 — replaced by [[Release 0.1.0 (Build 3)]] before its device pass ran.
> The `0.1.0 (2)` archive was uploaded to App Store Connect on 2026-07-28 as the second TestFlight candidate, but `0.1.0 (3)` was uploaded the same day before any physical-device check completed here. The physical-device pass now runs on Build 3 (its checklist plus the verification checklist below, which itself carries every Build 1 check). This note remains the historical record of the second cut. States and procedure = [[Deployment & Release]].
>
> **Cut evidence:**
> - **iOS:** archive cut from clean `main` at `ea1132b` (version bump PR #16). `xcodebuild archive` (cloud signing, team `35Q36KU73C`) → **ARCHIVE SUCCEEDED**; app and `PhotoDomeLiveActivity.appex` both stamped **0.1.0 (2)**; `xcodebuild -exportArchive` (app-store-connect / upload / automatic signing) → **Upload succeeded** + **EXPORT SUCCEEDED**. `ITSAppUsesNonExemptEncryption: false` is in the binary (PR #2), so no Missing Compliance hold is expected.
> - **API:** production unchanged this cycle — deploy run `30224158717` (2026-07-27) remains active; `/v1/health` and `/v1/health/ready` verified 200 with postgres/redis `ok` on 2026-07-28. All iOS PRs this cycle (#5–#16) were path-filtered out of the deploy pipeline by design.

## Scope

Seeded with carry-over; add new work here, not to the candidate.

- [x] Declare `ITSAppUsesNonExemptEncryption: false` (standard HTTPS/TLS only) so builds skip the Missing Compliance hold — PR #2, merged 2026-07-27

- [ ] ~~Fixes/findings from the Build 1 TestFlight device pass~~ — Build 1 was superseded before its device pass ran, and this build was superseded in turn; the pass now runs on [[Release 0.1.0 (Build 3)]] against its checklist plus the verification checklist below, and findings land in [[Release 0.1.0 (Build 4)]]
- [ ] Decide whether the App Store display name stays "Photodome App" or changes before first release ("PhotoDome" is taken; a trademark claim is possible via Apple's process if ever pursued) — carried to [[Release 0.1.0 (Build 4)]]
- [x] Green GitHub Actions after the billing fix — run `30224158717` (2026-07-27): verify 4m22s ✓, deploy 6m35s ✓, production `/v1/health` and `/v1/health/ready` 200 with postgres/redis `ok`

## Bug fixes

- [x] Constrain each event-album photo button to its visible rectangular grid cell so a clipped `scaledToFill` thumbnail cannot make the neighboring row intercept the tap and download the wrong photo. The new edge-tap UI regression failed before the fix (`Tapped bottom` for the upper tile) and passes afterward. [[2026-07-27 Event album – tap photo near grid-row edge – neighboring photo starts downloading]]
- [x] Refresh five-minute album thumbnail credentials on foreground or current-URL failure so lazy rows do not turn into gray placeholders after expiry. Stale failure callbacks are ignored and concurrent refreshes are coalesced; three URL-lifecycle regressions pass. [[2026-07-27 Event album – scroll or return after signed URL expiry – photos show gray placeholders]]
- [x] Show a selected or captured photo in the album grid immediately and overlay its preparing/uploading/processing loader on the image. Stable client and server identity handoffs prevent duplicate cells, and failed admitted transfers remain visible for tap-to-retry — PR #5, merged 2026-07-27. [[2026-07-27 Event album – select photo – upload appears only as a separate progress row]]
- [x] Present event start, end, expiry, and attendee-join timestamps in the iPhone's current timezone with a friendly localized name such as `Eastern Time`; if Foundation only supplies a numeric GMT/UTC offset, show `local time` instead. Three deterministic timezone/locale regressions pass — PR #7, merged 2026-07-28. [[2026-07-28 Event timestamps – view local expiry – raw GMT offset appears]]
- [x] Hide the unfinished **Share invite** action while invite URLs still use `photodome.invalid`, and make the remaining full-width **Copy code** action show a checked **Code copied** state for two seconds plus a VoiceOver announcement. The production-component UI regression proves sharing is absent and copy feedback appears — PR #8, merged 2026-07-28. [[2026-07-28 Event invite – tap Share invite – unfinished placeholder link is offered]] · [[2026-07-28 Event invite – tap Copy code – no confirmation appears]]
- [x] Attach repeat-download, photo-deletion, attendee-removal, rotate-code,
  end-event, and restrict-upload confirmations to the exact control that opened
  them instead of the event screen's root container. ID-scoped bindings preserve
  the selected repeated row, while screen-wide error alerts remain centered.
  The focused lower-row UI regression, signed unit suite, strict lint, and
  Release simulator build pass — PR #10, merged 2026-07-28.
  [[2026-07-28 Action confirmation – tap lower source – warning stays anchored
  near top]]
- [x] Remove the unfinished **Share transfer link** action from the Transfer
  host sheet: it exported the placeholder `photodome.invalid` URL carrying the
  live one-time host-transfer token the sheet itself says never to post
  publicly — the same defect class PR #8 removed from the invite card. The QR
  remains the only transfer path, and the focused UI regression proves the
  sheet renders QR-only with no share action — PR #15, merged 2026-07-28.
  [[2026-07-28 Host transfer – tap Share transfer link – unfinished
  placeholder link is offered]]
- [x] Bring the app-owned event camera up to a native capture baseline with
  front/back switching, visible Off/Auto/On flash, mirrored front capture,
  tap-to-focus/exposure, bounded pinch zoom, and an accessible 1×/2× zoom
  control. The one-shutter save/upload/return flow remains unchanged. Strict
  lint, all 46 signed unit tests, the focused camera-control UI regression, and
  the Release simulator build pass; physical camera hardware remains a named
  verification gate — PR #11, merged 2026-07-28.
  [[2026-07-28 Event camera – open capture – native camera controls are
  missing]]

## UX improvements

- [x] Make Home, live albums, and private review feel local-first. Event
  snapshots render before server reconciliation; album pages persist in
  protected storage; Kingfisher 8.10.0 provides bounded memory/disk caching,
  downsampling, prefetch, and stable keys across signed-URL rotation; cursor
  pages load near the grid tail; local masters use bounded ImageIO previews;
  and review decisions reveal the next prefetched card before the request
  returns. Strict lint, 53 signed simulator tests (48 passed, five opt-in API
  tests skipped), and the signed generic iOS Release build pass — PR #13,
  merged 2026-07-28.
  [[Local-First Event Media Cache]]
- [x] Make the host's **N attending** summary interactive. It opens a dedicated attendee sheet containing the non-removable host and every active guest; guests expose a confirmed Remove action, while non-host viewers retain a read-only count. Policy regressions cover host-only management and host protection, and a UI regression proves the count opens the sheet with the correct removal affordances — PR #6, merged 2026-07-28. [[M4 Host Lifecycle and Moderation]]
- [x] Add device-local event archiving to Home. Swipe a card right-to-left or long-press it to Archive; the new three-line top-left menu slides in from the left and opens Archives, where swipe and long-press expose Unarchive. Archiving persists across launches but preserves event access, queued transfers, realtime, and Live Activities. Two store regressions and one production-component UI flow cover persistence, stale-ID pruning, swipe archive, drawer navigation, and long-press unarchive. The complete scheme passes 55 tests with 50 passed, 5 opt-in API integration tests skipped, and zero failures; the Release simulator build succeeds — PR #9, merged 2026-07-28. [[M1 Accountless Event Spine]]
- [x] Add a permanent **View Archives** action to the Home empty state so a
  person can recover an accidentally archived event without discovering the
  menu first. Count-aware copy identifies archived events when present; the
  focused recovery flow, existing menu/unarchive flow, Home accessibility
  audit, all 46 signed unit tests, strict lint, and Release simulator build
  pass — PR #12, merged 2026-07-28. [[M1 Accountless Event Spine]]
- [x] Streamline the core iPhone flows around progressive disclosure and
  action-first copy. Home no longer reserves a drawer for its single Archives
  destination, event cards show only status, photo/people counts, host, and
  relative deletion timing, and an empty archive does not create a recovery
  action. The host invite moves from a permanent detail card into a focused
  sheet that opens after event creation and remains available from the toolbar.
  Permission setup excludes unrelated profile/privacy settings; Join accepts
  and normalizes a code from the keyboard; live events no longer expose the
  ended-event take-home action; and repeated album, camera, and privacy prose is
  removed. Format, lint, 49 unit tests, and all 15 UI flows and automated
  accessibility audits pass; five opt-in API integration tests skip without a
  live API — PR #14, merged 2026-07-28.

## Verification

- [ ] On a physical iPhone with a large real album, compare cold first open,
  warm reopen, fast scrolling, background/foreground after signed-URL expiry,
  offline relaunch, memory pressure, and low storage. Verify cached cells appear
  immediately, pagination has no duplicate/missing photos, review gestures show
  the next card without waiting, and event expiry/revocation removes protected
  local media.
- [ ] On a physical iPhone, open a real event with multiple grid rows and tap the center plus all four edges/corners of several tiles; verify only the touched tile starts downloading.
- [ ] On a physical iPhone, leave a multi-row album open for more than five minutes, background/foreground it, then scroll through previously unseen rows; verify every thumbnail loads and the server receives at most one recovery refresh for simultaneous stale failures.
- [ ] On a physical iPhone, import a batch and capture a camera photo on a throttled connection; verify each local photo appears in the grid before reservation finishes, survives background/foreground, transitions once to its ready server cell, and a failed admitted transfer retries from its photo tile.
- [ ] On a physical multi-camera iPhone, switch rear ↔ front, verify front
  mirroring, cycle rear Flash Off/Auto/On and confirm actual firing, tap near and
  far subjects to focus/meter, pinch through the supported zoom range, use the
  visible 1×/2× control with VoiceOver, and verify the shutter still saves,
  queues, and returns exactly once.
- [ ] As a host on a physical iPhone, tap **N attending**, verify the host and guests are listed, remove one guest after confirmation, and verify that guest immediately loses access while their row and the summary count disappear. Confirm a guest cannot open attendee management.
- [ ] On a physical iPhone set to Miami/Eastern Time, open an ended event and verify **Photos expire** shows the correct local date and clock time with `Eastern Time`, never `GMT-4`; then change the device timezone and verify the display follows it.
- [ ] As a host on a physical iPhone, verify the invite card shows QR plus one full-width **Copy code** action and no **Share invite** action; tap copy, paste the exact code elsewhere, and confirm **Code copied** appears and VoiceOver announces it.
- [ ] As a host on a physical iPhone, start a host transfer and verify the
  Transfer host sheet offers only the QR with its one-time/short-lived caption
  and warning copy — no **Share transfer link** action — and that scanning the
  QR on a second iPhone still completes the transfer.
- [ ] On a physical iPhone with live and ended cards, verify each compact card
  exposes status, photo/people counts, host, and any deletion countdown without
  clipping at large Dynamic Type. Swipe right-to-left and long-press separate
  events to archive them; after the last active card leaves Home, verify the
  count-aware **View Archives** action opens the expected cards. When active and
  archived events both exist, verify the direct Archives toolbar action appears.
  Confirm swipe/long-press Unarchive restores cards to Your Events and relaunch
  preserves archive state without interrupting a Live Activity or queued
  transfer.
- [ ] With separate host and guest iPhones, create and join an event end to end.
  Verify the invite sheet opens once after creation and remains reachable from
  the host toolbar, permission setup contains only the three required
  permissions, code entry submits from the keyboard, live events do not offer
  take-home, ended events do, and the simplified camera/album states remain
  understandable with VoiceOver and large Dynamic Type.
- [ ] On a physical iPhone, open repeat-download and delete confirmations from
  photos near the top and bottom of a long album, then open rotate/end/restrict
  and attendee-removal confirmations from scrolled controls. Verify each
  warning remains spatially associated with its tapped source; adaptive
  placement above or below is acceptable, but a fixed top/root source is not.

## Related

[[Deployment & Release]] · [[Release Versioning]] · [[Release 0.1.0 (Build 1)]]

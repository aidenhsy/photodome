---
type: plan
status: candidate
updated: 2026-07-28
---
# Release 0.1.0 (Build 3)

> [!warning] 🟡 CANDIDATE 2026-07-28 — closed to new scope.
> The `0.1.0 (3)` archive was uploaded to App Store Connect on 2026-07-28; this is an internal TestFlight candidate, **not** a shipped release. New work goes to [[Release 0.1.0 (Build 4)]]. The verification checklist stays live until the physical-device pass completes. This build supersedes [[Release 0.1.0 (Build 2)]], which was never device-passed; every Build 2 physical check (which itself carried every Build 1 check) runs here. States and procedure = [[Deployment & Release]].
>
> **Cut evidence:**
> - **iOS:** archive cut from clean `main` at `7b92ce7` (PR #21). `xcodegen generate` produced no diff at that commit; the pre-archive Release-configuration generic-device build passed. `xcodebuild archive` (cloud signing, team `35Q36KU73C`) → **ARCHIVE SUCCEEDED** at `~/Library/Developer/Xcode/Archives/2026-07-28/PhotoDome-0.1.0-3.xcarchive`; app and `PhotoDomeLiveActivity.appex` both stamped **0.1.0 (3)**; `xcodebuild -exportArchive` (app-store-connect / upload / automatic signing / `manageAppVersionAndBuildNumber: false`) → **Upload succeeded** + **EXPORT SUCCEEDED**. `ITSAppUsesNonExemptEncryption: false` verified in the built product, so no Missing Compliance hold is expected.
> - **API:** production deploy run `30313931529` (PR #21, 2026-07-27) remains active; `/v1/health` and `/v1/health/ready` verified 200 immediately before the archive on 2026-07-28.

`CURRENT_PROJECT_VERSION` was `3` in `photodome-ios/project.yml` for this cut;
after the upload it was bumped to `4` (PR #22, `36e9dbe`) per
[[Release Versioning]] — an uploaded version/build pair is never reused.

## Scope

- [ ] ~~Fixes/findings from the Build 2 TestFlight device pass~~ — Build 2 was superseded before its device pass ran; the pass now runs on this build against the verification checklist below plus [[Release 0.1.0 (Build 2)]]'s checklist, and findings land in [[Release 0.1.0 (Build 4)]]
- [ ] Decide whether the App Store display name stays "Photodome App" or changes before first release ("PhotoDome" is taken; a trademark claim is possible via Apple's process if ever pursued) — carried to [[Release 0.1.0 (Build 4)]]
- [ ] Remaining ASC metadata for the TestFlight/App Store record (carried to [[Release 0.1.0 (Build 4)]]; tracked in [[Release 0.1.0 (Build 1)]] → [[M7 Release Checklist]])

## Bug fixes

- [x] Isolate production media from development storage. Production had been
  configured with `photodome-dev`, so its durable database records could
  outlive objects removed by a development/manual cleanup path. A dedicated
  private `photodome-prod-younger7` bucket now serves production and passed
  policy, signed-read, anonymous-denial, and exact-deletion checks. The API
  now fails closed if production names a dev/development bucket and emits
  structured bucket-validation and photo-deletion records. Production now uses
  its own bucket-scoped service identity with access denied to development, and
  the development identity has been revoked from production. PR #20 is deployed
  as `fab3870` through green run `30312072615`. Five stale `READY` rows with no
  objects in either bucket were removed in one guarded transaction; two fresh
  uploads and all six of their objects were preserved beyond three
  reconciliation intervals. The exact historic deletion caller is `TBD`
  because GCS object Data Access audit logs were not enabled —
  [[2026-07-28 Event album – ready photos – GCS objects disappear]]

- [x] Restore the missing physical-lens choices in the event camera. The
  hard-coded 1×/2× toggle is now a device-aware preset row derived from the
  active camera's minimum zoom and virtual-device switch-over factors, with a
  supported 2× crop, smooth preset ramps, continuous pinch zoom, and simpler
  choices after front-camera switching. Swift format/lint, app-icon and Release
  configuration validation, all 59 unit tests with five expected live-API
  skips, all 17 UI tests, and the signed generic-device Release build pass.
  PR #19 is squash-merged as `304fb25`; physical multi-camera preset and
  optical-transition verification remains —
  [[2026-07-28 Event camera – open capture – native camera controls are missing]]

- [x] Prevent one physical invite scan from creating duplicate attendees.
  VisionKit now stops after the first valid QR detection, the join sheet claims
  one async submission, and the API uses a purpose-separated installation +
  invite binding so concurrent retries return one member/capability and publish
  one join signal. Removal clears the binding so an intentional rejoin remains
  possible. Production's two duplicate guest memberships were revoked after
  verifying zero contributed photos. The API format/lint/build/unit suite,
  complete five-suite E2E run, production image, Swift format/lint, 55-test
  unit scheme (50 passed, five expected live-API skips), all 16 UI tests, and
  signed generic Release build pass. PR #17 is deployed to production; both
  health probes return 200, the migration/index are present, and the remediated
  event has one active host and zero active guests. Physical QR verification remains —
  [[2026-07-28 Attendees – scan one invite – duplicate guest rows appear]]

## UX improvements

- [x] Remove the host-end dependency from photo take-home. Hosts and guests now
  see **Choose photos** and **Save current photos** during a live event as soon
  as one ready photo exists; after ending, the bulk label becomes **Save all**.
  Both controls remain in one horizontal row on narrower iPhones, with their
  decorative icons removed first and their complete labels scaling instead of
  wrapping.
  Private Keep/Skip/Undo and both `ALL` and `KEPT` manifests now accept live
  members, newly ready photos continue joining the remaining review queue, and
  device-saved photos stay deduplicated. API format/lint, 27 unit tests,
  production compilation, the PostgreSQL/GCS-backed curation E2E test, Swift
  format/lint, and the 62-test iOS unit target (57 passed, five expected
  live-API skips) pass. PR #21 is squash-merged as `7b92ce7`; main workflow
  run `30313931529` passed verify and deployed the API, and both production
  liveness/readiness probes return 200. The first post-merge verify attempt hit
  one transient PostgreSQL `P2034` conflict in the pre-existing reservation
  race test; the complete clean rerun passed before deployment —
  [[2026-07-28 Live Take-Home Availability Decision]]

- [x] Make photo contribution feel like one quick upload. The optimistic tile
  now keeps one **Uploading** label across preparation, transfer verification,
  and server processing; only failure asks for **Tap to retry**. Preparing,
  queued, and ready media share an exact square center-crop frame, preventing a
  portrait preview from stretching beyond its grid cell. Swift format/lint,
  all 74 scheme tests (69 passed, five expected live-API skips), the 17-test UI
  suite, visual portrait-fixture check, and signed generic Release build pass.
  PR #18 is merged as `b807556`; this is iOS-only and needs no API deploy —
  [[2026-07-28 Event album – upload preview – pipeline labels and portrait tiles complicate upload]]

## Verification

- [ ] On a physical multi-camera iPhone, open the rear event camera and verify
  the preset row includes every expected optical field of view for that device
  (including 0.5× where available), 1×, and the supported 2× crop. Tap each
  preset and confirm the preview transitions smoothly to the expected lens;
  pinch between presets; switch to the front camera and confirm unavailable
  rear presets disappear.

- [ ] On two physical iPhones, scan one invite while holding the QR in view
  through dismissal. Verify the guest enters once, the host sees one attendee
  row/count increment, and production receives at most one created membership.
  Remove the guest, then scan the still-valid invite again and verify one clean
  rejoin.

- [ ] On live host and guest sessions containing ready photos, verify both
  devices show **Choose photos** and **Save current photos** without ending the
  event. Keep and skip photos independently, add another contribution while
  review is open, and confirm it joins the remaining queue. Save the current
  set, add another photo, save again, and confirm only the new eligible photo is
  added. End the event and confirm the bulk label changes to **Save all**.

## Related

[[Deployment & Release]] · [[Release Versioning]] · [[Release 0.1.0 (Build 4)]] · [[Release 0.1.0 (Build 2)]] · [[Release 0.1.0 (Build 1)]]

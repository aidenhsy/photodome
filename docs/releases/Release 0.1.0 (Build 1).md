---
type: plan
status: superseded
updated: 2026-07-28
---
# Release 0.1.0 (Build 1)

> [!warning] ⚪ SUPERSEDED 2026-07-28 — replaced by [[Release 0.1.0 (Build 2)]] before its device pass ran.
> The `0.1.0 (1)` archive was uploaded to App Store Connect on 2026-07-27 as the first TestFlight candidate, but `0.1.0 (2)` was uploaded on 2026-07-28 before any physical-device check completed here. The physical-device pass now runs on Build 2 (its checklist carries every check), while the ASC-record items below that are build-independent (privacy answers, URLs, languages, crash reporting) stay tracked here until done or moved. This note remains the historical record of the first cut. States and procedure = [[Deployment & Release]].
>
> **Cut evidence:**
> - **iOS:** signing team `35Q36KU73C` and the `aps-environment` entitlement landed via PR #1 (squash-merged as `436d3d3`); archive cut from clean `main` at `8ee336f`. `xcodebuild archive` (cloud signing) → **ARCHIVE SUCCEEDED**; app and `PhotoDomeLiveActivity.appex` both stamped **0.1.0 (1)**.
> - **Upload:** `xcodebuild -exportArchive` (app-store-connect/upload, `manageAppVersionAndBuildNumber: false`) → **"Upload succeeded" / ** EXPORT SUCCEEDED **** (2026-07-27). Build number **1 is now burned**.
> - **App record:** created manually in ASC on 2026-07-27 — App Store display name **"Photodome App"** ("PhotoDome" was already taken), bundle id `com.younger7jp.photodome`. The display name can be changed in ASC until the first App Store release.
> - **API:** production live and healthy at `https://api.kindredarc.com` (`/v1/health` 200) on the same-day deploy recorded in [[Server Deployment]]. GitHub Actions remained billing-blocked, so the deploy ran manually with the workflow's exact script; CI verification ran locally, all green.

**Build number:** `MARKETING_VERSION` `0.1.0`, `CURRENT_PROJECT_VERSION` `1` in `photodome-ios/project.yml` at the cut commit. The project bumps to build `2` when the next archive is prepared.

## Scope

Everything through M6 plus the M7 local hardening tranche ([[M7 Local Release Hardening]]), with these gates closed at the cut:

- [x] Production deployment — API + postgres + redis behind `https://api.kindredarc.com` (2026-07-27, [[Server Deployment]]); GCS on the confirmed `photodome-dev` bucket
- [x] Release builds resolve the deployed API by default (`PHOTODOME_RELEASE_API_BASE_URL`)
- [x] Apple signing — team `35Q36KU73C`, cloud signing, APNs entitlement
- [x] ASC app record + archive + upload of `0.1.0 (1)`

## Verification checklist (live until acceptance)

- [x] TestFlight processing completed (Apple email, 2026-07-26 22:53 UTC); internal-tester invite sent to aidenhsy@gmail.com
- [ ] Missing Compliance hold released in ASC (build lacked `ITSAppUsesNonExemptEncryption`; declared for future builds in PR #2) and the build confirmed installable in the TestFlight app on a device
- [ ] Remaining ASC records: privacy answers (must cover precise location and embedded photo metadata), privacy-policy URL, support URL/contact, export compliance, TestFlight test information
- [ ] Crash reporting / observability decisions (provider, thresholds, owner — `TBD`)
- [ ] First-release language decision (binary is Base English only)
- [ ] Two-iPhone physical-device matrix from [[M7 Release Checklist]] with recorded evidence: create → QR/code join → live album contribution (camera + library) → host end/restriction → seven-day curation/download → Live Activity lifecycle incl. push updates (production APNs)

## Related

[[Deployment & Release]] · [[Release Versioning]] · [[M7 Release Checklist]] · [[Server Deployment]] · [[Release 0.1.0 (Build 2)]]

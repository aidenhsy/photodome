---
type: spec
status: active
updated: 2026-07-26
---
# M7 Release Checklist

## Overview & Context

**The pitch** — Turn the locally complete PhotoDome MVP into a signed, privacy-complete TestFlight build that has passed accessibility, production-configuration, and physical-iPhone regression gates.

**Strategic alignment** — The accountless create → join → upload → live album → end/restrict → curate/save journey is already implemented. M7 prevents a locally working build from being mistaken for a releasable one.

**Current state** — [[M7 Local Release Hardening]] records the completed local tranche: fail-closed production configuration, dependency readiness, response hardening, a bundled privacy manifest and in-app privacy explanation, Base-English localization extraction, four automated accessibility audits, a generated-client regression, and a successful unsigned Release archive. [[2026-07-26 Media Fidelity Decision]] is implemented locally: full-resolution JPEG masters retain embedded GPS/source metadata without a server re-encode, PhotoDome camera capture requires foreground precise location and embeds the shutter-time coordinate, the privacy manifest/usage string/disclosure are updated, and automated iOS plus GCS-backed tests cover the policy. App Store privacy answers, physical-device evidence, Apple signing, and production gates remain.

## Goals & Non-Goals

### Goals

- Produce a signed archive using the real production HTTPS API URL and Apple team.
- Pass the named regression matrix on at least two physical iPhones.
- Complete App Store Connect privacy, export-compliance, support, and TestFlight metadata.
- Ship and verify the approved full-resolution, metadata-preserving master pipeline without repeated lossy master encoding.
- Require foreground precise-location authorization for PhotoDome camera capture, embed the shutter-time coordinate, and avoid background/Always location access.
- Connect production health/metrics/crash evidence to an accountable operator.
- Reach a fully green checklist without describing an unsigned/local build as released.

### Non-Goals

- Finalize the business model or launch audience.
- Change the approved PhotoDome identity or app-icon geometry without a new product decision.
- Add product analytics or tracking by default.
- Add languages beyond Base English before first-release languages are confirmed.
- Select a hosting, crash-reporting, or alerting vendor without an explicit decision.

## Users & Scenarios

- As a beta attendee, I want permission, capture, upload, and save flows to work with VoiceOver and large text so that I can participate without avoidable accessibility barriers.
- As a beta host, I want host authority, Live Activity, moderation, and ending behavior to survive real-device and network transitions.
- As the operator, I want an invalid production configuration to fail before deployment so that PhotoDome cannot silently ship against localhost, an emulator, or incomplete APNs/metrics credentials.
- As the App Store reviewer, I need accurate privacy and support information that matches the binary.

## Acceptance Criteria

### Local gates

- [x] Given the backend is configured for production, when it boots with a GCS emulator endpoint, development pepper, debug/trace logging, missing metrics token, non-production APNs environment, or incomplete APNs credentials, then validation fails.
- [x] Given PostgreSQL and Redis are available, when `GET /v1/health/ready` is requested, then both dependencies report ready; a dependency failure returns unavailable.
- [x] Given an API response, then cache, MIME-sniffing, framing, referrer, and browser-permission security headers are present.
- [x] Given the iOS app is archived, then `PrivacyInfo.xcprivacy` and the Live Activity extension are embedded and the app reports version `0.1.0` build `1`.
- [x] Given a Release build without a non-local HTTPS URL, then the build fails; given an explicit HTTPS URL, an unsigned archive succeeds.
- [x] Given the home, create, join, and privacy surfaces, then Xcode's automated contrast, hit-region, description, Dynamic Type, clipping, and trait audits pass.
- [x] Given the live local API, then all five generated Swift-client integration tests pass.
- [x] Given the backend test environment, then 25 unit tests, 11 E2E tests, compilation, lint/format, and the production dependency audit pass.

### Apple and production gates

- [x] Given the approved icon, when the archive is inspected, then opaque 1024×1024 default, dark, and tinted renditions are present in `Assets.car`, and Xcode emits the packaged app-icon sizes.
- [ ] Given the selected production infrastructure, when deployed, then the API, PostgreSQL, Redis, private GCS bucket, workload identity, domain/TLS, cleanup workers, and backups are verified.
- [ ] Given production observability, when readiness or cleanup SLOs fail, then dashboards and accountable alert routing receive the signal. Vendor, thresholds, and owner are `TBD`.
- [ ] Given the selected crash strategy, when a beta build crashes, then the owner can retrieve a symbolicated report. A third-party provider is `TBD`; none is currently bundled.
- [ ] Given App Store Connect, when the build is uploaded, then signing, bundle records, privacy answers, privacy-policy URL, support URL/contact, export compliance, and TestFlight test information are complete.
- [x] Given a contributed supported JPEG containing GPS and other embedded metadata, when another authorized member downloads the master, then the full-resolution asset retains identical bytes and has not undergone repeated lossy master encoding.
- [x] Given PhotoDome camera capture, when foreground precise location is allowed, then the master embeds the shutter-time coordinate; when location is denied, restricted, or reduced accuracy, capture remains unavailable with a Settings recovery path.
- [x] Given a library import without GPS, when it is contributed, then PhotoDome does not attach the device's current/import-time location.
- [x] Given the metadata-preserving binary, then its bundled privacy manifest, foreground-location usage string, and in-app copy account for precise location and other embedded photo metadata available to authorized event members.
- [ ] Given App Store Connect, when privacy answers are reviewed, then they account for precise location and other embedded photo metadata and match the final deployed behavior.
- [ ] Given at least two signed iPhones, when the physical-device matrix below runs, then evidence is recorded with device/OS/build and pass/fail notes.
- [ ] Given the first TestFlight audience, then supported languages are explicitly decided. The binary currently uses Base English only.

## Proposed Solution & UX

The Release build remains visually black and white. Privacy and retention are reachable from the home screen, and accountless behavior, private storage, required foreground precise location for camera capture, embedded-metadata retention, authorized-member access, and seven-day deletion are explained in-app. Exact contributor disclosure/acknowledgement copy is `TBD`.

The TestFlight description should present PhotoDome as an accountless shared event album. Suggested “What to Test” copy:

> Create an event on one iPhone, join from another using the QR or code, contribute camera and library photos, end the event, restrict new uploads, privately keep/skip photos, and save all or kept originals. Please report permission, background-transfer, Live Activity, VoiceOver, or large-text problems.

### Physical-iPhone regression matrix

- Camera and foreground precise-location allow, deny, restrict, reduced-accuracy, Settings recovery, capture quality, and shutter-time GPS embedding.
- Multi-select PhotoKit import, embedded GPS/source-metadata preservation, full-resolution fidelity, and add-only save permission.
- Large upload under weak network, interruption, backgrounding, termination, relaunch, session expiry, and retry.
- Two-device create/join, Socket.IO updates, join-code rotation, host transfer, removal/revocation, and offline/reconnect behavior.
- Live Activity allow/deny, Lock Screen-to-camera interaction count, sandbox APNs READY-count update, and host-end termination.
- Post-end upload, restriction race, and completion of reservations admitted before restriction.
- Different private keep/skip sets on two attendees and background save-all/save-kept retry.
- Shortened-TTL expiry rehearsal proving both devices lose access and every GCS generation plus server metadata is deleted.
- iCloud-synchronizable Keychain recovery on an eligible signed device pair.
- VoiceOver and accessibility text sizes through the primary journey.

## Alternatives Considered

| Option | Benefit | Cost / reason not selected |
|---|---|---|
| Submit after simulator tests only | Fastest path | Cannot prove camera, Photos, Keychain sync, ActivityKit/APNs, background transfer, or signed-device behavior. |
| Add analytics/crash SDK immediately | More telemetry | Vendor, consent, privacy disclosure, and operating owner are undecided; adding one now would invent policy. |
| Use an unrelated generated icon | Fast visual change | Breaks the approved dome-frame identity and reproducible vector-to-PNG workflow. |
| Claim multiple languages from extracted strings | Broader listing | No translations or first-release language decision exist. |

## Technical & Cross-Cutting Concerns

- The production API URL is supplied as `PHOTODOME_RELEASE_API_BASE_URL` and must resolve to non-local HTTPS.
- Production backend validation requires a metrics bearer token and complete production ActivityKit APNs credentials.
- The current privacy manifest declares photos/videos, precise location linked to the contribution, other user content, and a linked installation/device identifier for app functionality; tracking is false. The in-app disclosure explains that authorized event members can download embedded GPS and other photo metadata. The external privacy policy and App Store Connect answers still require review against deployed behavior.
- The signed app must include accurate foreground location usage text. PhotoDome does not need background/Always location for the approved capture flow.
- No advertising, cross-app tracking, product analytics SDK, or third-party crash SDK is included.
- App Store privacy answers must be derived from actual deployed behavior and the binary, then reviewed by the legal/product owner.
- Production storage must keep the M6 invariant: database object keys are retained until all GCS generations are verified deleted.

## Milestones & Open Questions

### Completed locally — 2026-07-25

- Production fail-closed backend and iOS configuration.
- Dependency readiness and response security headers.
- Privacy manifest, privacy surface, accessibility fixes, and automated audits.
- Base-English extraction settings, version/build settings, Release archive, and complete local regressions.

### Remaining before external TestFlight

- [ ] Select production hosting/region and provision every dependency.
- [ ] Supply Apple Developer team/signing and create App Store Connect records.
- [ ] Supply public privacy-policy and support URLs/contact.
- [ ] Confirm export-compliance answers.
- [ ] Decide Base-English-only versus additional first-release languages.
- [ ] Decide crash reporting, metrics dashboard/alerts, thresholds, and owner.
- [ ] Run and record the two-iPhone matrix.

## Related

- [[Architecture and Implementation Plan v0]]
- [[Product Discovery Brief]]
- [[Media Upload and Retention]]
- [[M6 Expiry Security and Scale]]
- [[M7 Local Release Hardening]]
- [[Release Versioning]]
- [[PhotoDome Design System]]
- [[PhotoDome Design System Reference]]
- [[Design Spec Rules]]

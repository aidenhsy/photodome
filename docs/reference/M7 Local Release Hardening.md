---
type: reference
status: shipped
updated: 2026-07-28
---
# M7 Local Release Hardening

Reference doc for the M7 controls that are implemented and verified locally. It complements the still-active [[M7 Release Checklist]]; PhotoDome is not yet a signed or externally distributed TestFlight build.

Created 2026-07-25 when local release configuration, privacy, accessibility, readiness, and archive verification landed.

Added 2026-07-26 when the approved icon was archive-verified, the first-beta version policy was confirmed, and the precise-location/metadata-preserving media amendment shipped locally.

## At a glance

The backend now fails closed on unsafe production configuration, exposes dependency readiness, sends defensive response headers, shuts down cleanly, and preserves full-resolution private masters while generating optimized metadata-free variants. The iOS app requires foreground precise location for capture, embeds shutter-time GPS, preserves imported photo metadata, embeds an updated privacy manifest, explains privacy/retention in-app, uses Base-English string extraction, refuses unsafe Release API URLs, carries automated accessibility audits, and includes the approved app icon. A production-shaped unsigned archive succeeds, but signing, production services, App Store metadata, and physical-device proof remain external gates.

## Backend behavior

Production environment validation rejects:

- `GCS_API_ENDPOINT`, which prevents an emulator from entering production;
- the exact development capability pepper;
- `debug` or `trace` logging;
- a missing metrics bearer token;
- any ActivityKit APNs environment other than `production`; and
- missing APNs bundle, team, key, or private-key credentials.

`GET /v1/health/ready` executes a PostgreSQL `SELECT 1` and Redis `PING`. It reports both dependencies as ready or returns HTTP 503; this is distinct from the liveness endpoint.

Every configured API response keeps `Cache-Control: no-store` and adds `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, and a camera/microphone/geolocation-denying `Permissions-Policy`. Nest shutdown hooks allow infrastructure termination signals to close providers cleanly.

## iOS privacy and accessibility

`PrivacyInfo.xcprivacy` is bundled in the app archive. It declares:

- photos/videos for app functionality;
- precise location linked to the photo contribution for app functionality;
- the participant display name used to identify hosts and attendees inside private sessions;
- other user content for app functionality;
- the accountless installation/device identifier for app functionality; and
- no tracking.

On first launch, a single “What’s your name?” field can be completed or left with Back. Its value is stored in device-local Keychain and accompanies new create/join requests without creating an account. Back returns to Home without inventing an identity; Create or Join presents the name prompt again before continuing. Home is deliberately reduced to Your Events, restored event cards, persistent Create an event and Join an event actions, and one top-right Settings gear. Archives stays hidden while empty; when needed, it opens directly from the current-event toolbar or a count-aware empty-state action rather than a one-item drawer. Cards keep only lifecycle, photo/attendee counts, host relationship, and a relative deletion countdown. Join remains only on Home; Settings has no redundant top-left Join action. The Your name row opens a focused editor; saving updates the device value and propagates it across existing event memberships with realtime refresh. Settings keeps live Camera, Photos, and Precise Location permission states, first-request actions, denied/restricted/reduced-accuracy recovery through iOS Settings, and privacy/retention details together. Required create/join setup hides unrelated profile/privacy rows and shows only a short prompt, the three permissions, and Continue. PhotoDome requests When In Use location only, never background/Always location. The event creation form does not ask for a place in 0.1.0.

Event detail keeps the album above secondary management content. Its compact
lifecycle row replaces repeated role and timestamp text, the host invite
QR/code opens once after creation and remains available from a toolbar button,
live events do not show take-home actions, and empty albums or the camera no
longer repeat instructions already conveyed by their adjacent controls.

The in-app disclosure states that camera captures include their precise shutter location, imported photos retain their own embedded metadata, and authorized event members can download that metadata. The location usage string and privacy manifest match this behavior.

Accessibility changes include semantic labels/hints, decorative-image hiding, dynamic text styles, a darker secondary text token, persistent input labels, high-contrast primary actions, Reduce Motion behavior in photo review, and VoiceOver-friendly QR/join-code descriptions.

User-facing alerts map transport and generated-client failures to short recovery-oriented copy. Connection failures say that PhotoDome cannot connect and suggest trying again shortly; alerts never expose request URLs, identifiers, error domains, or generated-client diagnostics. Known product failures such as invalid invitations and capacity limits retain their specific messages.

Four UI tests run Xcode accessibility audits on home, event creation, joining, and Settings. Each checks contrast, hit regions, descriptions, Dynamic Type, text clipping, and traits. A fifth UI test proves that a new create flow stops at the permission setup with Continue disabled when required access is missing.

## Release configuration

The checked-in project sets marketing version `0.1.0`, build `1`, Base English, and string extraction. Debug uses the local API. Release expands `PHOTODOME_RELEASE_API_BASE_URL`, which since 2026-07-27 defaults in `project.yml` to the deployed `https://api.kindredarc.com` (see [[Server Deployment]]) and can still be overridden at archive time; a pre-build script requires non-local HTTPS, and runtime validation also rejects HTTP outside localhost Debug builds.

The first TestFlight line is `0.1.0 (1)`. Additional binaries for that same beta keep marketing version `0.1.0` and increment the build to `2`, `3`, and so on. `0.0.1` is not used because this is the first usable end-to-end MVP beta rather than an initial scaffold build.

The verified unsigned archive contains:

- bundle `com.younger7jp.photodome`;
- version `0.1.0` build `1`;
- an explicitly supplied HTTPS API URL;
- `PrivacyInfo.xcprivacy`; and
- `PhotoDomeLiveActivity.appex`.

The local archive is production-shaped and contains the approved 1024×1024
default, dark, and tinted app-icon renditions. It is still not uploadable proof
because production code signing and App Store configuration are absent.

## Verification through 2026-07-26

Backend:

- Prettier, ESLint, NestJS compilation, and 25 unit tests passed.
- Eleven PostgreSQL/Redis/GCS-backed E2E tests passed, including byte-for-byte master preservation after variant processing.
- `npm audit --omit=dev` reported zero known production dependency vulnerabilities.

iOS:

- Swift format and lint passed.
- The standard simulator suite proves precise-location authorization mapping, shutter-time GPS/date embedding, byte-for-byte JPEG metadata preservation, and no import-time GPS substitution; five live-API tests remain intentionally skipped without a live API.
- The integration scheme then passed all five generated-client tests against the live local backend.
- All four automated accessibility audits passed.
- The missing-URL Release build failed as designed.
- The explicit-HTTPS unsigned Release archive succeeded, and its privacy manifest passed `plutil`.

## Decisions and gotchas

- The milestone is split deliberately: local release hardening is shipped, while TestFlight is not complete.
- Version `0.1.0 (1)` is the first beta; build numbers increase for every uploaded replacement binary.
- No analytics or crash SDK was added because vendor, consent, disclosure, and operational ownership remain `TBD`.
- Base English is configured, but that does not decide supported first-release languages.
- The app icon now implements [[PhotoDome Design System]] with deterministic
  vector masters, opaque PNG exports, and archive-level asset-catalog proof.
- The privacy-policy URL, support URL/contact, legal owner, App Store privacy answers, export compliance, and beta contact belong in App Store Connect and remain external inputs.
- Simulator accessibility audits do not replace VoiceOver and accessibility-size checks on real devices.

## Key files

- `photodome-api/src/common/config/env.validation.ts`
- `photodome-api/src/modules/health/application/check-readiness.use-case.ts`
- `photodome-api/src/modules/health/presentation/health.controller.ts`
- `photodome-api/src/common/http/configure-app.ts`
- `photodome-ios/PhotoDome/PrivacyInfo.xcprivacy`
- `photodome-ios/PhotoDome/Features/Foundation/PrivacyView.swift`
- `photodome-ios/PhotoDome/Services/PermissionCenter.swift`
- `photodome-ios/PhotoDomeUITests/AccessibilityUITests.swift`
- `photodome-ios/Scripts/validate-release-configuration.sh`
- `photodome-ios/Scripts/render-app-icons.swift`
- `photodome-ios/Scripts/validate-app-icons.sh`
- `photodome-ios/PhotoDome/Design/PhotoDomeTokens.swift`
- `photodome-ios/project.yml`

## Related

- [[M7 Release Checklist]]
- [[Release Versioning]]
- [[Architecture and Implementation Plan v0]]
- [[M6 Expiry Security and Scale]]
- [[Media Upload and Retention]]
- [[Reference Doc Rules]]

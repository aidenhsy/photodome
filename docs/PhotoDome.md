---
type: project
status: active
updated: 2026-07-26
---
# PhotoDome

## Goal

Build the easiest way for everyone at an event to contribute to one live photo album, then let each attendee take home either the complete album or only their personally selected favorites.

## Current state

- The source code lives in this repository (`photodome-api/`, `photodome-ios/`, `photodome-design-system/`), with these docs under `docs/`.
- M0 through M6 and the local M7 hardening tranche are complete: the NestJS/SwiftUI product flow, verified expiry/security/scale work, production configuration guards, dependency readiness, privacy manifest/copy, accessibility audits, and an unsigned Release archive are implemented and verified locally.
- The initial product explanation is captured in [[2026-07-25 Product Walkthrough]].
- The host/guest journey and proposed MVP are documented in [[Product Discovery Brief]].
- Hosts and guests use PhotoDome without creating accounts.
- The product is iPhone-only, with a native iOS client and required Live Activity / Lock Screen capture entry.
- The backend uses NestJS and follows foodapp's core architecture and supporting stack.
- The host explicitly ends the live event, but new and queued uploads remain allowed afterward unless the host restricts uploads.
- Event photos are retained for seven days after the event ends.
- Uploads already reserved/in progress finish after the host restricts new uploads.
- Host authority is an event-scoped capability stored in iCloud-synchronizable Keychain, with a one-time transfer QR/deep link; no account or recovery form is required.
- Event originals, derived images, and server metadata are permanently deleted from a dedicated private GCS bucket at expiry.
- The real `photodome-dev` bucket passes policy, resumable upload, Sharp variant, signed-read, anonymous-denial, and exact-prefix deletion checks documented in [[GCS Development Bucket Validation]].
- Events are private to code holders; ready uploads appear immediately; host can remove photos/attendees and rotate the join code.
- Swipe right keeps, left skips, Undo reverses the latest choice, and selections remain private.
- The shipped pipeline keeps a full-resolution downloadable JPEG master with embedded GPS and other source metadata, plus separate metadata-free display/thumbnail variants. Supported JPEG imports stay byte-for-byte unchanged; other supported stills are encoded at most once at high quality. PhotoDome camera capture requires foreground precise-location authorization, embeds the shutter-time coordinate, and never substitutes import-time location for a library photo.
- V1 targets 100 attendees, 2,000 photos, and 20 MB per original.
- PhotoDome is the final product name. Its permanent design system is black and white, with full-color event photography, SF Rounded product type, an 8-point layout rhythm, adaptive appearances, and accessible semantic states.
- The approved dome-frame app icon ships as default, dark, and tinted 1024×1024 assets and is verified in the Release archive.
- Signing/App Store setup, production deployment, physical-device regression, first-release languages, crash/alerting ownership, and business model remain undecided or unavailable.

## Next actions

- [x] Capture the initial product explanation in [[2026-07-25 Product Walkthrough]].
- [x] Distill the explanation into a one-sentence product definition.
- [x] Identify the primary roles: event host and attendee.
- [x] Map the core journey and a proposed MVP.
- [x] Confirm the first platform and core application/backend framework.
- [x] Confirm accountless guest joining and host-controlled event ending.
- [x] Confirm accountless hosting, post-end upload behavior, host upload restriction, and seven-day retention.
- [x] Decide accountless host recovery, in-progress upload behavior, GCS storage, and permanent cleanup.
- [x] Confirm privacy, moderation, swipe semantics, image policy, and initial scale limits.
- [x] Approve [[Product Discovery Brief]].
- [x] Write [[Architecture and Implementation Plan v0]].
- [x] Confirm the temporary black-and-white visual direction.
- [x] Confirm PhotoDome as the final product name and approve the permanent monochrome identity.
- [x] Ship [[PhotoDome Design System]] and [[PhotoDome Design System Reference]].
- [x] Ship and archive-verify the production default, dark, and tinted app icon.
- [x] Scaffold the application from the approved implementation plan in [[M0 Development Foundation]].
- [x] Ship the local accountless event spine in [[M1 Accountless Event Spine]].
- [x] Ship M2 direct private-GCS upload and the live shared album in [[M2 Direct Upload and Live Album]].
- [x] Ship M3 native camera capture and the Live Activity / Lock Screen entry in [[M3 Camera and Live Activity]].
- [x] Verify the real development GCS bucket and private media lifecycle in [[GCS Development Bucket Validation]].
- [x] Ship M4 host lifecycle, post-end controls, and moderation in [[M4 Host Lifecycle and Moderation]].
- [x] Ship M5 private swipe curation and source-quality download in [[M5 Personal Curation and Download]].
- [x] Ship M6 verified expiry cleanup, security hardening, and scale validation in [[M6 Expiry Security and Scale]].
- [x] Ship the local M7 release-hardening tranche in [[M7 Local Release Hardening]].
- [x] Adopt the `0.1.0 (1)` first-beta and parallel-release policy in [[Release Versioning]].
- [x] Approve full-resolution master and embedded-metadata preservation in [[2026-07-26 Media Fidelity Decision]].
- [x] Require foreground precise-location authorization for the in-app camera and embed its capture coordinate.
- [x] Implement and locally verify required location authorization plus embedded GPS/source-metadata preservation without repeated lossy master encoding.
- [x] Update the bundled privacy manifest, location usage string, and in-app contributor disclosure for retained photo metadata.
- [ ] Complete and review App Store Connect privacy answers for retained precise location and photo metadata.
- [ ] Complete the Apple, production, and physical-device gates in [[M7 Release Checklist]].
- [ ] Confirm hosting/deployment, business model, and launch success measures.

## Key references

- [[2026-07-25 Product Walkthrough]]
- [[2026-07-26 Media Fidelity Decision]]
- [[Product Discovery Brief]]
- [[Architecture and Implementation Plan v0]]
- [[PhotoDome Design System]]
- [[PhotoDome Design System Reference]]
- [[M0 Development Foundation]]
- [[M1 Accountless Event Spine]]
- [[M2 Direct Upload and Live Album]]
- [[M3 Camera and Live Activity]]
- [[M4 Host Lifecycle and Moderation]]
- [[M5 Personal Curation and Download]]
- [[M6 Expiry Security and Scale]]
- [[M7 Release Checklist]]
- [[M7 Local Release Hardening]]
- [[Release Versioning]]
- [[GCS Development Bucket Validation]]
- [[Design Spec Rules]]
- [[Reference Doc Rules]]

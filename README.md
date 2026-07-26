# PhotoDome

PhotoDome is a shared event-photo app. An accountless host creates an event and shares a QR code or short code; accountless guests join the live album, contribute photos from the camera or camera roll, and see everyone else's photos as the event unfolds. The host ends the live event, but uploads remain open unless the host restricts them. Everyone has seven days after the event ends to contribute, download the full album, or swipe through it to keep only the photos they want.

## Project documentation

The canonical project knowledge base lives in the Obsidian brain vault:

`/Users/aidenyang/Documents/brain/10 Projects/photodome`

Start with:

1. `README.md` — documentation map and working rules.
2. `meetings/2026-07-25 Product Walkthrough.md` — raw product explanation and decisions.
3. `specs/Product Discovery Brief.md` — the approved product definition and MVP scope.
4. `specs/Media Upload and Retention.md` — GCS, background upload, image, and expiry design.
5. `specs/Architecture and Implementation Plan v0.md` — build-ready architecture, contracts, milestones, and release gates.
6. `specs/PhotoDome Design System.md` — permanent identity, tokens, components, and accessibility rules.
7. `reference/Release Versioning.md` — marketing versions, build numbers, TestFlight rebuilds, patches, and parallel release lines.

## Current status

- Product explanation: captured
- Core users: event hosts and attendees
- Identity: neither hosts nor guests need accounts
- Core journey: create → join → contribute/view live → host ends → optional late uploads → select → save
- Lifecycle: uploads stay open after ending unless the host restricts them; photos expire seven days after the event ends
- Recovery: host capability restores automatically through iCloud-synchronizable Keychain, with one-time device-transfer QR as fallback
- Client: iPhone-only native iOS app, including ActivityKit/Live Activity
- Backend: NestJS, following foodapp's architecture and supporting stack
- Media: private Google Cloud Storage with durable direct uploads, full-resolution metadata-preserving JPEG masters, optimized metadata-free browsing variants, and permanent seven-day cleanup
- GCS development: real `photodome-dev` policy, private media lifecycle, signed reads, and exact-prefix cleanup verified
- Product/technical plans: approved
- Implementation: M0–M6, the local M7 release-hardening tranche, and required precise-location/metadata-preserving capture are complete; production deployment, Apple/App Store setup, and physical-iPhone regression remain
- Brand: PhotoDome is the final name; the permanent black-and-white design system is implemented in SwiftUI and an interactive reference
- App icon: approved default, dark, and tinted 1024×1024 dome-frame assets are compiled by Xcode
- Design reference: private production site at `https://photodome-design-system.aidenhsy.chatgpt.site`

## Repository layout

```text
photodome-api/  NestJS API, Prisma foundation, tests, and local services
photodome-design-system/  Interactive design reference and portable token files
photodome-ios/  SwiftUI app, Live Activity extension, tests, and generated client
```

## Local setup

The repository expects Node.js 22 or newer, Docker, Xcode 26 or newer, and
XcodeGen.

Start the API:

```bash
cd photodome-api
cp .env.example .env
npm install
npm run prisma:generate
docker compose up -d
npm run prisma:migrate:deploy
npm run start:dev
```

The health contract is available at `http://127.0.0.1:3000/v1/health`,
Swagger UI at `http://127.0.0.1:3000/api`, and the OpenAPI document at
`http://127.0.0.1:3000/api-json`.

M1 adds accountless event creation/join, private event snapshots, join-code
rotation, and one-time host transfer. M2 adds private direct resumable media
uploads, verification and Sharp variants, short-lived reads, Socket.IO album
updates, a persistent iOS background transfer queue, byte-preserved JPEG
masters, and metadata-free browsing variants. M3 adds native camera capture
with required foreground precise location, shutter-time GPS, a one-shutter
save-and-share flow, permission-safe PhotoKit
fallback, repeatable capability-free capture deep links, whole-surface Live
Activity capture routing, event-member token registration, and optional
ActivityKit APNs READY-count updates. M4 adds idempotent host end, the seven-day
expiry clock, post-end upload restriction with grandfathered reservations,
attendee/photo removal, realtime revocation, verified GCS deletion tombstones,
and ActivityKit end delivery. M5 adds member-private keep/skip/Undo,
paginated review and signed-original manifests, realtime incoming/removal
handling, and a persistent background queue that saves all or kept photos to
Apple Photos. M6 adds delayed all-generation expiry cleanup, independent retry
tombstones, reconciliation/orphan cleanup, protected Prometheus metrics,
fail-closed bucket checks, secret-redaction proof, and a repeatable
100-member/2,000-photo scale gate. The local M7 tranche adds production
configuration guards, PostgreSQL/Redis readiness, response hardening, privacy
manifest/copy for precise location and retained photo metadata, automated
accessibility audits, Base-English extraction, and
Release URL/archive checks. PostgreSQL is published on `5434`, Redis on
`6381`, and the local GCS emulator on `4443`.

Generate and open the iOS project:

```bash
cd photodome-ios
Scripts/regenerate-api.sh
open PhotoDome.xcodeproj
```

`regenerate-api.sh` exports the NestJS OpenAPI document offline, regenerates
the checked-in Swift client, and refreshes the Xcode project. The default
`PhotoDome` scheme runs unit tests. With the local API running,
`PhotoDome-Integration` proves the two-client event flow and that a guest's
direct upload appears in the host album. The simulator uses
`http://127.0.0.1:3000`; override `PHOTODOME_API_BASE_URL` with the Mac's LAN
URL for an iPhone.

## Verification

```bash
cd photodome-api
npm run format:check
npm run lint
npm test -- --runInBand
npm run test:e2e -- --runInBand
npm run build
npm run scale:verify
npm run gcs:verify

cd ../photodome-ios
Scripts/lint.sh
xcodebuild -project PhotoDome.xcodeproj \
  -scheme PhotoDome \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The current product definition and remaining open decisions are in
`specs/Product Discovery Brief.md`. As-built details are in the vault's
`reference/M1 Accountless Event Spine.md` and
`reference/M2 Direct Upload and Live Album.md`,
`reference/M3 Camera and Live Activity.md`, and
`reference/M4 Host Lifecycle and Moderation.md`, and
`reference/M5 Personal Curation and Download.md`, and
`reference/M6 Expiry Security and Scale.md`, and
`reference/M7 Local Release Hardening.md`. The active external release gates
are in `specs/M7 Release Checklist.md`, and durable deployment numbering is in
`reference/Release Versioning.md`. Real-bucket verification is in
`reference/GCS Development Bucket Validation.md`.

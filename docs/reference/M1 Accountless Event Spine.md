---
type: reference
status: shipped
updated: 2026-07-28
---
# M1 Accountless Event Spine

M1 is complete locally in this repository. It provides a working private event that an accountless host can create and an accountless guest can join by QR or short code. A later 0.1.0 simplification added a one-field first-launch display name so hosts can recognize attendees and everyone can see who owns a session, without adding login or account registration.

## Shipped user flow

1. On first launch, the iPhone asks “What’s your name?” and stores the trimmed display name in device-local Keychain. Back returns to Home without creating a placeholder identity; Create or Join asks again before continuing.
2. The iPhone app creates a named event; location and cover entry are hidden in 0.1.0, and successful creation navigates directly into the new event.
3. The API returns a high-entropy host capability once and an eight-character public join code.
4. The app stores the event access in an iCloud-synchronizable Keychain item and shows the host's QR plus manual code. The host can copy the code with visible and VoiceOver confirmation. External invite-link sharing stays hidden while the app still uses its non-routable placeholder domain.
5. A guest scans the normal invite QR or enters the code and receives a distinct guest capability without creating an account; their saved device display name becomes part of that event membership. The scanner accepts one valid detection, and concurrent retries from the same installation/invite return that same membership and capability instead of creating phantom attendees.
6. Both clients can retrieve the same private event snapshot; the snapshot includes lifecycle state, member count, creator display name, and the current viewer's role.
7. The host can see attendees by name, and every participant can see who owns the session.
8. Tapping Your name in Settings opens a small editor. Saving updates the device-local value and every existing event membership still accessible to that device; realtime clients refresh named attendee and host displays.
9. The host can rotate the public join code. The old code stops admitting guests, while existing member capabilities continue to work.
10. The host can create a distinct, one-time, short-lived transfer QR. Exchanging it atomically rotates host authority; the previous host capability becomes invalid immediately.
11. On launch, the app restores saved events from Keychain and refreshes their server snapshots. A confirmed invalid or unavailable capability is removed; a network failure retains the recoverable capability.
12. Home and event detail show start time and, for ended events, end time converted to the iPhone’s current timezone. The timezone uses a friendly localized name, or `local time` instead of a numeric GMT/UTC offset. Ended Home cards use a muted fill, border, and explicit Ended label.
13. On Home, swiping an event right-to-left or long-pressing it exposes Archive. A three-line top-left menu slides in from the left and opens Archives; archived cards remain navigable and expose Unarchive through the same swipe and long-press paths. When Your Events is empty, the high-contrast empty state also presents View Archives directly. It explains where archived events live and, when present, states their count so an accidentally archived event is discoverable without knowing about the menu. Archive IDs persist in device-local `UserDefaults` and are pruned when the corresponding saved capability is forgotten. Archiving never removes the Keychain capability or interrupts uploads, downloads, realtime access, or Live Activities.

The iOS home, create, join, event, invite, rotate, and host-transfer surfaces
were built on the M0 monochrome foundation. Their shared `AppTheme` facade now
resolves through the permanent [[PhotoDome Design System]] tokens.

## Backend implementation

### Persistent model

The first Prisma migration creates:

- `Event` with UUID, required name, creator display name, reserved optional location/cover reference, `LIVE | ENDED | EXPIRING` state, hashed current join code, lifecycle timestamps, and upload-restriction timestamp.
- `EventMember` with event-scoped UUID, 1–50 character display name, `HOST | GUEST` role, hashed capability, optional purpose-separated join-binding hash, removal timestamp, and join timestamp.
- `HostTransferToken` with server-hashed token, expiry, consumption timestamp, and event relation.

The M1 capacity limit is 100 active members. Join admission runs in a serializable PostgreSQL transaction and retries serialization/unique conflicts. The guest binding combines the normalized invite code with the device-local installation signal through a purpose-separated HMAC; it is unique within the event and cannot authorize event access. A repeated request returns the same member and deterministic guest capability without publishing another join signal. Host removal clears the binding and replaces the revoked capability hash so an intentional later rejoin remains possible.

### Capability security

- Event and transfer capabilities contain 32 random bytes with distinct `pdc_` and `pdt_` prefixes.
- Raw capabilities are returned only at issuance/exchange and are never stored in PostgreSQL.
- Capability, transfer-token, and join-code hashes use purpose-separated HMAC-SHA256 with `CAPABILITY_PEPPER`.
- The event guard hashes the bearer candidate and compares it against at most 100 active member credentials using constant-time comparison.
- Host-only routes enforce the member role after capability validation.
- Pino redacts authorization, installation identity, capabilities, join codes, and transfer tokens.
- API responses use `Cache-Control: no-store`, including responses that issue raw capabilities or invite material.
- Create and join routes have independent IP, installation-identity, and event/code throttle keys. The event/code signal is hashed before it becomes a throttle key. Join also uses the installation signal in a purpose-separated retry binding; installation identity alone remains non-authorizing.
- Invalid, rotated, consumed, or expired invites use non-disclosing not-found behavior.

### API operations

| Method | Path | OpenAPI operation |
|---|---|---|
| `POST` | `/v1/events` | `createEvent` |
| `POST` | `/v1/events/join` | `joinEvent` |
| `GET` | `/v1/events/:eventId` | `getEvent` |
| `PATCH` | `/v1/events/:eventId/members/me` | `updateOwnEventDisplayName` |
| `POST` | `/v1/events/:eventId/rotate-code` | `rotateEventJoinCode` |
| `POST` | `/v1/events/:eventId/host-transfer` | `createHostTransfer` |
| `POST` | `/v1/host-transfers/exchange` | `exchangeHostTransfer` |

Swagger remains available at `/api`, and the checked-in Swift client is regenerated from the offline OpenAPI export.

## iOS implementation

- `InstallationIdentityStore` creates a random, device-local Keychain identity on first use. It is sent as `X-PhotoDome-Installation-ID` for abuse control and idempotent join correlation, never as event authorization.
- `DeviceProfile` stores the person’s display name in a separate, device-only Keychain item. It is presentation data, never authorization.
- `KeychainCapabilityStore` stores one encoded access record per event as a synchronizable generic-password item. The raw capability is not written to `UserDefaults`, a file, logs, or UI.
- `CapabilityAuthMiddleware` injects the event bearer capability only for authorized operations.
- `APIClient` maps generated OpenAPI DTOs into app-owned event models at the service boundary.
- `EventRepository` coordinates API calls, capability persistence, snapshot refresh, code rotation, and transfer exchange.
- Normal invite and host-transfer payloads use distinct `/join` and `/host-transfer` routes.
- QR generation uses Core Image; QR scanning uses VisionKit's `DataScannerViewController`; the eight-character code is always available as fallback.
- VisionKit stops scanning immediately after its first valid invite, and the join sheet independently prevents a second async submission while the first is running.

The local QR base is deliberately `https://photodome.invalid`. A production domain, Associated Domains entitlement, Apple App Site Association file, and App Store handoff remain TBD and must be configured together rather than inventing a production URL.

## Local operation

```bash
cd photodome-api
cp .env.example .env
npm install
docker compose up -d
npm run prisma:migrate:deploy
npm run start:dev
```

The Compose PostgreSQL service is published on `127.0.0.1:5434`; the API listens on `127.0.0.1:3663`.

```bash
cd photodome-ios
Scripts/regenerate-api.sh
open PhotoDome.xcodeproj
```

The simulator default is `http://127.0.0.1:3663`. For a physical iPhone on the same network, override the `PHOTODOME_API_BASE_URL` Xcode build setting with the Mac's reachable LAN API URL. Do not commit machine-specific addresses.

## Verification completed on 2026-07-25

Backend:

- Prettier and ESLint passed.
- Four unit tests passed.
- Four PostgreSQL-backed E2E tests passed.
- NestJS production compilation passed.
- The E2E suite proves private create/join, member count, host-only authorization, rotation, old-code rejection, existing-member continuity, one-time transfer, replay rejection, and old-host revocation.

iOS:

- SwiftFormat and SwiftLint passed.
- The app and Live Activity extension built for the iOS simulator.
- Theme, invite/deep-link parsing, and signed simulator Keychain round-trip/update/removal tests passed.
- The live integration scheme passed against the local API with two independent installation identities and capabilities.
- The app launched on an iPhone 17 Pro simulator and the M1 home surface rendered correctly.

## Empty-Home archive recovery verification on 2026-07-28

- The visible empty-state recovery path shipped to `main` through PR #12.
- The production-component UI regression archives the only event, verifies the
  count-aware empty-state copy, opens Archives from the visible recovery action,
  and finds the archived card.
- The existing menu-driven archive/unarchive regression still passes.
- The complete Home automated accessibility audit passes after the new empty
  state adopts the required high-contrast typography.
- Strict Swift format/lint, all 46 signed unit tests with five expected opt-in
  live-API skips, and the unsigned Release simulator build pass.

## Idempotent invite-join verification on 2026-07-28

- A production physical scan exposed two VisionKit callbacks and two real guest
  rows 0.614 seconds apart; both rows were revoked after confirming zero
  contributed photos.
- A PostgreSQL-backed E2E regression submits the same install/invite twice
  concurrently and proves one member ID, one active guest, one capability,
  member count `2`, and a clean remove/rejoin path.
- The complete five-suite API E2E run, production Docker image build, strict
  API format/lint/build and 26 unit tests pass.
- The complete iOS scheme passes 55 unit tests (50 passed, five expected
  opt-in live-API skips), all 16 UI/accessibility tests, strict Swift
  format/lint, and the signed generic Release build.
- Physical two-iPhone QR verification remains open in [[Release 0.1.0 (Build
  3)]].

## Device validation still required

The local milestone is shipped, but these hardware/ecosystem checks are not claimed as complete:

- iCloud Keychain synchronization between two signed-in physical iPhones.
- VisionKit QR scan and camera-permission behavior on physical hardware.
- Universal-link open/install handoff after a real production domain is selected.
- Host transfer by scanning from one physical iPhone to another.

These checks remain release gates; they do not change the implemented M1 API or app behavior.

## M1 boundary

Not implemented in M1:

- Event cover upload.
- Photo capture/import, GCS reservation/upload, variants, or signed delivery.
- Socket.IO album updates.
- Event end, late uploads, upload restriction, member/photo moderation.
- Save all, swipe review, Undo, or Photos-library download.
- Seven-day GCS/database deletion.
- Production deployment, domain, signing, or TestFlight.

M2 was subsequently delivered; see [[M2 Direct Upload and Live Album]].

## Related

- [[Architecture and Implementation Plan v0]]
- [[Product Discovery Brief]]
- [[Media Upload and Retention]]
- [[M0 Development Foundation]]
- [[M2 Direct Upload and Live Album]]

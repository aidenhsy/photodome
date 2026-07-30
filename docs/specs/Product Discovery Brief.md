---
type: spec
status: planned
updated: 2026-07-28
---
# Product Discovery Brief

> Approved MVP definition for PhotoDome, distilled from [[2026-07-25 Product Walkthrough]] and amended by [[2026-07-26 Media Fidelity Decision]] and [[2026-07-28 Live Take-Home Availability Decision]], following [[Design Spec Rules]]. Confirmed behavior is separated from non-blocking open questions.

MVP product decisions approved 2026-07-25. PhotoDome is the final product name,
and the permanent black-and-white identity is specified in
[[PhotoDome Design System]]. Remaining business-model, hosting,
and launch choices do not block the engineering implementation.

## Overview & Context

**The pitch** — PhotoDome is a live shared photo album for real-world events. A host creates an event and shares a QR code or short code; attendees join, view and contribute photos throughout the event, then take home the photos currently available or a personal selection made with a Tinder-style left/right review without waiting for the host to end the event.

**Strategic alignment** — PhotoDome turns event photography from a fragmented after-event chore into a shared activity that happens while the event is still alive. Its wedge is the complete loop: near-instant joining, low-friction Lock Screen capture, one pooled live album, and fast personal curation at the end.

**Current state** — The approved MVP and local M7 hardening tranche are implemented. Accountless create/join, private direct media upload, live album, native capture and Live Activity, host lifecycle/moderation, private curation/source-original saving, verified seven-day cleanup, security/scale controls, production configuration guards, privacy manifest/copy, automated accessibility audits, and the approved app icon are in place. The 2026-07-26 media amendment is also shipped locally: downloadable JPEG masters retain embedded GPS/source metadata without a server re-encode, compatible JPEG imports remain byte-for-byte unchanged, PhotoDome camera capture requires foreground precise location and embeds the shutter-time coordinate, and imports never receive import-time location. Production deployment, Apple/App Store setup, physical-device regression, and TestFlight remain; see [[M7 Release Checklist]], [[M7 Local Release Hardening]], and [[2026-07-26 Media Fidelity Decision]].

**Problem today** — Birthday parties and other events produce photos across many attendees' phones. Collecting them later requires chasing people, searching group chats, opening drive links, or managing separate shared albums; attendees then have to sort through everything manually to find the photos they care about.

## Goals & Non-Goals

### Proposed MVP goals

1. Let a host create an event without an account and share access through both a scannable QR code and a short join code.
2. Let an attendee join the correct event without creating an account and see the shared album.
3. Let every permitted attendee contribute new camera captures and existing camera-roll photos.
4. Keep the album visibly live as attendees contribute, with one simple
   user-facing **Uploading** state while preparation, transfer verification,
   and variant processing continue automatically.
5. Provide an iOS Live Activity / Lock Screen entry that gets an attendee from the event to capture in no more than two interactions, following the product principle in the foodapp "Meal Lifecycle PRD" (external note, not included in this repo).
6. When the host ends the event, transition out of the live phase while continuing to accept queued and new uploads unless the host restricts them.
7. From the first ready contribution through the seven-day post-end window, let each attendee either save every currently available photo or swipe through the album to build and download a personal selection.
8. Before a person creates or joins an event, complete one permission preflight for Camera, Photos add access, and foreground precise location; keep current permission status and recovery actions together in Settings.
9. Ask for one display name on first launch, retain it on the device without an account, and use it to identify the host and attendees inside sessions.
10. Preserve the supported source photo's full-resolution visual content and embedded metadata, including GPS when present, in the downloadable master while using optimized variants for fast browsing.

### Non-goals until requested

- A general-purpose public social network or public event-discovery feed.
- Professional photo editing, filters, retouching, or print ordering.
- Video, captions, comments, reactions, AI curation, or facial recognition.
- Public sharing outside the event membership model.
- Android, web, and desktop clients; the product is iPhone-only.

## Users & Scenarios

### Users

| Role | Need | Current alternative | Priority |
|---|---|---|---|
| Event host | Create one place for the event's photos and get everyone into it quickly | Group chat, shared album, cloud folder, or asking guests afterward | Must |
| Event attendee | Contribute and see photos without interrupting the event, then take home the desired set | Send photos manually and search several people's uploads later | Must |

The host is also an attendee for viewing, contributing, selecting, and saving. The host ends the event, can remove attendees, can rotate the join code, and can restrict new uploads. Each attendee can delete only photos they contributed.

### Scenario A — host starts an event

> As an **event host**, I want to **create an event and show one QR/code**, so that **every guest can join the same live photo space without exchanging individual contact details**.

1. On first launch, the host enters the display name that PhotoDome remembers on the device.
2. Host completes the Camera, Photos add, and foreground precise-location permission preflight if any decision has not already been granted.
3. Host creates an event with only a required event name in 0.1.0; cover and location entry are deferred.
4. PhotoDome creates the event without requiring registration and grants the creator host control.
5. PhotoDome generates a QR code plus short join code.
6. Host displays the invite QR or copies the short code. External link sharing remains hidden until a production invite domain and universal-link handoff are implemented.
7. Host sees attendees by their saved display names as they arrive.

### Scenario B — attendee joins and contributes

> As an **attendee**, I want to **join quickly and add photos throughout the event**, so that **the group builds one complete album while the event is happening**.

1. On first launch, the attendee enters the display name that PhotoDome remembers on the device.
2. Attendee opens the QR/code join path.
3. PhotoDome requires the one-time Camera, Photos add, and foreground precise-location permission preflight if any decision has not already been granted.
4. The attendee scans the QR code or enters the short code.
5. PhotoDome resolves the event and lets the attendee join without creating an account, attaching the saved display name to that event membership.
6. The attendee sees the existing shared photos and who hosts the session.
7. They capture a new photo or choose one or more photos from the camera roll.
8. The contribution uploads to the event and becomes visible immediately to other authorized attendees once processing succeeds.
9. While the event is active, its Live Activity stays available on the Lock Screen / Dynamic Island and leads back to fast capture.

### Scenario C — attendee takes photos home

> As an **attendee**, I want to **save everything or quickly choose only my favorites**, so that **I leave with the memories I want without tedious gallery cleanup**.

1. As soon as a live event has a ready photo, PhotoDome presents **Choose photos** and **Save current photos** to every participant.
2. Save current photos downloads the eligible album snapshot; a later repeat omits photos already saved on that device.
3. Choose photos opens a one-photo-at-a-time swipe deck while the event is live or ended, and new ready photos join the remaining queue.
4. After the host ends the live event, the bulk action is labeled **Save all** during the seven-day post-event window.
5. Queued uploads finish, and attendees may continue adding photos unless the host restricts uploads.
6. Swipe right keeps a photo, swipe left skips it, and Undo reverses the most recent choice.
7. PhotoDome shows the chosen set and saves it to the attendee's photo library.

### Edge scenarios

- Invalid, expired, revoked, or mistyped join code.
- Camera or photo-library permission denied or limited.
- Offline capture, intermittent connectivity, failed upload, and upload retry.
- A new photo arriving while someone is swiping or downloading.
- Duplicate imports of the same camera-roll photo.
- Very large events and albums.
- A contributor deletes their photo while another attendee is viewing or downloading it.
- An attendee leaves and later rejoins.

## Acceptance Criteria

The following criteria define the approved MVP.

- **Given** a valid new event, **when** the host creates it, **then** PhotoDome presents a QR code and short code that both resolve to that same event.
- **Given** the host submits a valid event name, **when** creation succeeds, **then** PhotoDome closes the creation sheet and navigates directly into the new event.
- **Given** a first launch with no saved display name, **when** PhotoDome opens, **then** it asks “What’s your name?” and retains the answer locally without requiring an account; Back returns to Home, and Create or Join presents the name prompt again before continuing.
- **Given** a person opens Settings, **when** they tap Your name and save a valid change, **then** PhotoDome updates the device name and their memberships in existing events, including live attendee lists and host attribution.
- **Given** a person who creates or joins an event, **when** another authorized participant views that session, **then** the host name and attendee display names identify whose session it is and who joined.
- **Given** a person opens Home, **when** events are restored, **then** the surface shows the Your Events list, persistent Create an event and Join an event actions, and one top-right Settings icon. Archives stays hidden when empty; when archived events exist, it is one tap away from the current-event list or the count-aware empty state.
- **Given** a person starting the create or join flow, **when** Camera, Photos add access, or foreground precise location is not ready, **then** PhotoDome presents the centralized permission setup before allowing the session flow to continue.
- **Given** a denied/restricted Camera or Photos decision, or denied/restricted/reduced-accuracy location authorization, **when** the person opens PhotoDome Settings, **then** the corresponding row shows the current state and provides a route to iOS Settings.
- **Given** a new host with no PhotoDome account, **when** they create an event, **then** they receive host control without completing account registration.
- **Given** a valid invite, **when** an attendee scans the QR or enters the code, **then** they enter the intended event and can view its available photos.
- **Given** one valid invite scan or a retried join request, **when** the same installation submits it more than once, **then** PhotoDome creates one attendee membership and returns the same event capability.
- **Given** a new guest with no PhotoDome account, **when** they use a valid invite, **then** they can join and participate without completing account registration.
- **Given** an authorized attendee, **when** they capture or import a supported photo, **then** one square, center-cropped optimistic tile appears immediately with a stable **Uploading** state and becomes a ready album photo without exposing internal preparation, verification, or processing stages.
- **Given** Camera and foreground precise-location authorization, **when** an attendee captures through PhotoDome's camera, **then** the master embeds the authorized capture coordinate.
- **Given** location is denied, restricted, or reduced to approximate accuracy, **when** an attendee attempts to use PhotoDome's camera, **then** capture remains unavailable and the app explains how to enable precise location in iOS Settings.
- **Given** an imported photo, **when** it contains no GPS metadata, **then** PhotoDome does not substitute the device's current/import-time location.
- **Given** a supported source photo containing embedded GPS or other metadata, **when** another authorized event member downloads its master, **then** the retained metadata survives the contribution and download round trip.
- **Given** a supported source that requires normalization, **when** PhotoDome creates its downloadable master, **then** it avoids repeated lossy master encoding and retains full pixel dimensions.
- **Given** a contributor deleting their own photo or a host removing an attendee, **when** the action succeeds, **then** that subject loses event visibility/access immediately and every connected client receives the change.
- **Given** a host who rotates the join code, **when** someone uses the previous code, **then** it no longer admits a new attendee while existing attendees retain access.
- **Given** an active event and enabled Live Activities, **when** an attendee uses the Lock Screen capture affordance, **then** they reach the event camera in no more than two interactions.
- **Given** Live Activities are disabled, **when** the attendee uses the app normally, **then** joining, viewing, capturing, and saving still work.
- **Given** photo-library access is limited, **when** the attendee imports, **then** PhotoDome only exposes the system-authorized items and explains how to add more.
- **Given** a live or ended event with at least one ready photo, **when** an attendee uses the bulk-save action, **then** PhotoDome saves every currently available eligible event photo, omits photos already recorded as saved on that device, and labels the live action **Save current photos**.
- **Given** an attendee chooses swipe review, **when** they keep and skip photos, **then** PhotoDome preserves the decisions through the review and downloads only the final kept set.
- **Given** an attendee swipes right, **when** the choice is recorded, **then** the photo is kept; a left swipe skips it, and Undo reverses the most recent decision.
- **Given** one attendee's swipe decisions, **when** another attendee views the event, **then** those personal decisions are not visible and do not remove photos from the shared album.
- **Given** an upload or download failure, **when** connectivity returns, **then** the operation can be retried without silently duplicating or losing the item.
- **Given** an active event, **when** its host ends it, **then** every participant sees that the live phase has ended and is offered the take-home flow.
- **Given** an ended event whose host has not restricted uploads, **when** a queued upload resumes or an attendee starts a new upload, **then** PhotoDome continues accepting it.
- **Given** an ended event, **when** its host restricts uploads, **then** PhotoDome blocks new upload reservations while allowing every already-reserved/in-progress upload to finish.
- **Given** an ended event, **when** seven days have elapsed since `endedAt`, **then** PhotoDome makes the event unavailable and permanently deletes its originals, variants, and server metadata from GCS and the database.

## Proposed Solution & UX

### High-level flow

```text
Host creates event
  -> PhotoDome generates QR + short code
  -> Attendees join the same private event
  -> Everyone views and contributes to the live album
       -> camera
       -> camera roll
       -> Lock Screen / Live Activity entry
       -> choose photos or save current photos
  -> Host ends live phase
       -> uploads remain open unless host restricts
       -> save all
       -> swipe keep/skip -> review selection -> save
  -> Seven days after ending: event media expires
```

### Initial surface inventory

| Surface | User purpose | MVP? | Notes |
|---|---|---|---|
| Home / events | Create or join an event, return to joined events without an account, and move less-relevant events out of the primary list | Must | Your Events shows current local cards with persistent Create and Join actions and Settings at top right. Swipe an event right-to-left or long-press it to Archive. When current and archived events both exist, a direct Archives button appears at top left; when no current events remain, the empty state exposes View Archives with the archived count. Archive navigation stays hidden when there is nothing to recover. Archiving is device-local presentation state: it never deletes the Keychain capability, server event, media, queued work, realtime access, or Live Activity. Cards show only lifecycle, photo and attendee counts, the viewer’s host relationship, and an ended event’s relative deletion countdown. |
| First-launch name | Let other session members recognize this person without creating an account | Must | One required display name, retained in device-local Keychain and reused for new event memberships. |
| Create event | Name the event | Must | 0.1.0 asks only for the required event name. Cover and location entry are deferred. |
| Event invite | Display the QR and copy the short code | Must | A newly created event opens a focused invite sheet immediately. After dismissal, a persistent event-toolbar Invite button reopens the QR, short code, and copy action instead of placing a large invite card above the album. Private to code holders; host can rotate the code. Copy confirms success visually and to VoiceOver. External link sharing is hidden while the invite URL still uses the non-routable development placeholder. |
| Join event | Scan QR or enter code without creating an account | Must | Guest event capability persists in iCloud-synchronizable Keychain; the invite can be scanned again if still valid. |
| Settings and permissions | Edit the saved display name and review or recover Camera, Photos add, and foreground precise-location access in one place | Must | Opened from the single Home Settings icon. Tapping Your name opens a focused editor and propagates the change to existing memberships. Joining remains a primary Home action rather than an extra Settings shortcut. When create/join requires setup, the sheet shows only a short prompt, the three permission rows, and Continue; profile and privacy navigation remain in regular Settings. |
| Live event album | View incoming photos and event state | Must | Ready photos appear immediately; designed for up to 100 attendees and 2,000 photos. Preparing and queued contributions use the same square, center-cropped tile geometry and one **Uploading** label; internal verification/processing stages stay hidden unless an actionable failure requires **Tap to retry**. The navigation bar is the single event-title location. A compact lifecycle row keeps Live/Ended, attendance, upload admission, and deletion countdown readable without repeating role or timestamps. For the host, tapping **N attending** opens the attendee list with confirmed removal controls for guests; the host row is visible but not removable. Guests see a read-only count. Album badges distinguish the viewer's own contributions from photos already saved through PhotoDome. The full photo tile downloads an unsaved contribution on tap, while the arrow remains as the visual cue. Empty albums rely on the adjacent Camera and Photos actions instead of explanatory body copy. |
| Event camera | Capture directly into the event | Must | Opens with the rear camera and exposes front/back switching, Off/Auto/On flash when supported, tap-to-focus/exposure, and pinch plus accessible discrete zoom. The familiar shutter and upload preview communicate the one-tap flow without a persistent coaching banner. One shutter press captures without a separate review/confirmation step, saves the new photo to Photos, queues its event upload, and returns to the event. The viewer's own contribution never needs to enter take-home selection or download. |
| Camera-roll picker | Import existing photos | Must | Multi-select; maximum 20 MB per original. |
| Live Activity | Show active event and open fast capture | Must on iOS | Uses a large monochrome Lock Screen hierarchy: bold event name, `LIVE EVENT · N PHOTOS`, oversized camera cue, and a full-width labeled capture action with no thumbnail or invented progress. The live surface opens capture; counts update locally and through optional ActivityKit APNs delivery. |
| Take-home | Choose photos or bulk-save without depending on the host ending the event | Must | **Choose photos** and **Save current photos** appear for hosts and guests during a live event as soon as at least one ready photo exists. The bulk label becomes **Save all** after ending. New ready photos join the remaining private review queue, while the viewer's own contributions and locally recorded completed saves are excluded from repeat selection and saving. Actions stay hidden with zero ready photos and while expiring. |
| Host controls | End the live event and restrict post-event uploads | Must | Shown below the photo grid so the album remains the primary event content. End event uses the danger-red treatment. Restriction blocks new reservations; already-reserved/in-progress uploads finish. |
| Swipe review | Keep/skip one photo at a time | Must | Right = keep, left = skip, Undo available, choices private. |
| Selection review | Confirm and download kept photos | Should | Prevent accidental loss before saving. |

### Interaction principles

- **Set permissions once, then stay in the moment:** Camera, Photos add, and foreground precise-location access are prepared before create/join so capture, geotagging, and saving do not introduce permission surprises during an event.
- **Keep failures understandable:** User alerts show a short recovery-oriented message and never expose generated-client diagnostics, URLs, request identifiers, or networking internals.
- **Keep confirmations attached to their action:** A photo, attendee row, or
  host-control warning uses that exact control as its adaptive presentation
  source, including after scrolling. Screen-wide failures remain screen-modal.
- **Stay in the moment:** capture should feel closer to the system camera than to composing a social post.
- **The event album is shared; the take-home set is personal:** the pooled memory remains intact while each attendee curates privately.
- **Keep transfer state simple and actionable:** show one **Uploading** state for
  uninterrupted contribution work, and expose retry only when the person must
  act. Internal preparation, verification, and processing stages remain
  observable to the system without becoming extra steps in the album.
- **No nagging Live Activity:** use it as a quiet event-state/capture surface, not an engagement prompt.
- **Take-home does not depend on the host:** live participants can curate or save the currently ready snapshot; ending closes the live phase, changes the bulk label to **Save all**, and starts the seven-day expiry window while contribution remains possible until the host restricts it.

## Alternatives Considered

| Option | Benefits | Costs / risks | Current view |
|---|---|---|---|
| Group chat uploads | Familiar and already installed | Compression, noisy conversation, fragmented saving, weak album experience | The behavior PhotoDome should beat |
| OS shared album | Strong native photo experience | Setup/membership friction and platform boundaries; no purpose-built event wrap-up | Important competitor/benchmark |
| Cloud-drive folder | Cross-platform and simple storage | Weak live capture and browsing experience | Useful fallback, not the target UX |
| Notifications instead of Live Activity | Broader compatibility | Interruptive and poor as a persistent active-event surface | Live Activity preferred on iOS |
| Automatic AI favorites | Less manual sorting | Trust/privacy risk and not requested | Out of scope; swipe selection is explicit |

## Technical & Cross-Cutting Concerns

### Confirmed application stack

- **Client:** iPhone-only native Swift/SwiftUI application.
- **Apple frameworks:** ActivityKit for the Live Activity and Lock Screen/Dynamic Island entry; PhotoKit for camera-roll import and saving; native camera capture.
- **Backend:** NestJS 11 + strict TypeScript, following foodapp's Clean Architecture module layout (`domain`, `application`, `infrastructure`, `presentation`).
- **Database:** PostgreSQL through Prisma, using schema-first migrations and UUID identifiers.
- **Realtime:** Socket.IO for live event membership/photo updates, with ActivityKit push updates for backgrounded devices where needed.
- **Media:** dedicated private Google Cloud Storage bucket with direct resumable uploads, signed reads, optimized variants, and permanent seven-day cleanup.
- **Jobs:** Redis + BullMQ for background media processing, fan-out, cleanup, and retryable work where required.
- **Contract:** Swagger/OpenAPI generated by NestJS and consumed by an OpenAPI-generated Swift client.
- **Operations:** Pino structured logging and foodapp-style unit/E2E test, lint, format, migration, and deployment conventions.

This is a focused reuse of foodapp's core framework—not a requirement to copy unrelated maps, restaurant, social, or AI dependencies.

### Event and access model

- Core entities are an event, accountless host/member relationships with display names, scoped credentials, photos, upload state, and private attendee selections.
- Neither hosts nor guests create accounts. Host authority is a high-entropy event capability stored in iCloud-synchronizable Keychain; intentional device transfer uses a short-lived one-time QR/deep link and rotates the capability. Public join credentials never grant host authority.
- The app keeps one display name in device-local Keychain and sends it when creating or joining. The backend retains that display name only as part of the event membership and deletes it with the event.
- If the original phone is lost and iCloud Keychain is unavailable, host control is not recoverable; this is safer than weakening the public join code. The event still expires automatically.
- Join codes need sufficient entropy, expiration/revocation behavior, rate limiting, and a clear answer to whether code possession alone grants access.
- The host can end the live event, restrict uploads, remove attendees, and rotate the join code. Photo deletion belongs to the contributing member only.

### Live album and media pipeline

- Preserve a full-resolution downloadable master and generate thumbnails/previews separately from it. Preserve encoded source pixels where supported; otherwise use at most one high-quality full-resolution normalization rather than repeatedly re-encoding the master.
- Preserve source orientation, capture time, GPS, and other embedded metadata in the downloadable master. Require foreground precise-location authorization and embed the capture coordinate for PhotoDome camera photos. Preserve an imported source's existing GPS without replacing missing GPS with the device's import-time location.
- Use direct resumable object-storage uploads so large media does not bottleneck the application API.
- Define idempotency and content hashing to avoid duplicate uploads on retry/import.
- The album needs live change delivery or short polling; exact latency and scale target are not yet set.
- The durable upload and cleanup design is specified in [[Media Upload and Retention]].

### iOS capture and Live Activity

- Native iOS capability is required for ActivityKit, Lock Screen/Dynamic Island presentation, camera, and PhotoKit.
- PhotoDome camera capture requires foreground precise-location authorization. Denied, restricted, or reduced-accuracy location keeps capture unavailable and provides a Settings recovery path.
- The precedent in the foodapp "Meal Lifecycle PRD" (external note, not included in this repo) demonstrates the desired low-friction interaction: the Live Activity represents an active real-world session, and tapping its visible surface or camera affordance deep-links directly to its camera.
- Remote counts or last-photo state from other attendees would require server-to-ActivityKit push updates; own-device changes can update locally.
- Live Activities are optional at the OS level, so the core flow must not depend on permission being granted.
- If a photo thumbnail appears in the Live Activity, downsample it and use an app-group handoff rather than decoding a full-resolution image in the widget process.

### Privacy and safety

- Event photos may contain faces, children, homes, location metadata, and private behavior.
- Events are private to people holding a valid join capability; there is no public event-discovery surface.
- The host can rotate the join code and remove attendees. Every member can delete only their own contributed photos.
- Personal keep/skip choices are private and never mutate the shared album.
- Preserve source visual quality and embedded metadata—including capture date, orientation, GPS, and other source EXIF—in the private downloadable master.
- Before contribution, disclose that authorized event members may download precise location and other embedded metadata. Exact disclosure/acknowledgement UX is `TBD`.
- Retained image metadata must remain inside the authorized media object and must not be copied into logs, traces, or analytics.
- Decide whether removed photos disappear immediately from pending downloads and cached devices.

### Downloads and lifecycle

- Bulk downloads need clear progress, cancellation, background behavior, storage estimation, and partial-failure recovery.
- Saving to the iOS photo library requires add permission; denial should not destroy the attendee's selection.
- Keep the full-resolution, metadata-preserving master for download during the seven-day window, plus optimized display and thumbnail variants for browsing.
- The host moves the event from active to wrap-up. Queued and new uploads remain possible afterward unless the host restricts them.
- Store event photos for seven days after `endedAt`; then make the event inaccessible, delete every object under its GCS prefix, verify the prefix is empty, and only then discard database media keys/metadata.
- Cleanup uses delayed BullMQ work, retries, a reconciliation sweep, and metrics. The PhotoDome bucket has soft delete and Object Versioning disabled so expired bytes do not remain billable.
- Retention and storage economics still depend on original resolution and event size.

### Initial scale envelope

- Up to 100 attendees per event.
- Up to 2,000 photos per event.
- Up to 20 MB per original upload.
- Architecture must reject over-limit reservations predictably and expose a user-readable error; these are v1 product limits, not claims about the platform's eventual ceiling.

### Initial analytics candidates

- Event created.
- Invite displayed/shared.
- Join attempted/succeeded/failed by QR vs code.
- Photo captured/imported/uploaded/failed.
- Time from join to first viewed photo and first contribution.
- Wrap-up opened.
- Save all vs swipe review chosen.
- Swipe review completed/abandoned.
- Photos selected and successfully saved.

## Milestones & Open Questions

### Milestones

1. Core product explanation and journey captured — complete 2026-07-25.
2. Fully accountless participation, iPhone-only platform, NestJS/foodapp-style stack, host-controlled ending/upload restriction, and seven-day retention confirmed — complete 2026-07-25.
3. Accountless host recovery, in-progress upload admission, GCS provider, and permanent deletion mechanics confirmed — complete 2026-07-25.
4. Privacy, image quality/metadata, moderation, and scale decisions approved — complete 2026-07-25.
5. MVP brief and acceptance criteria approved — complete 2026-07-25.
6. [[Architecture and Implementation Plan v0]] written — complete 2026-07-25.
7. Application scaffolded — complete 2026-07-25.
8. Host-create → guest-join → pooled-upload vertical slice working — complete 2026-07-25.
9. Live Activity capture plus live and post-event save/select flow working — complete locally 2026-07-25 and amended 2026-07-28.
10. Verified expiry cleanup, security hardening, observability, and v1 scale gate — complete locally 2026-07-25.
11. M7 local release hardening — complete 2026-07-25; physical-device, production deployment, Apple/App Store, and TestFlight gates remain pending.
12. Full-resolution master, embedded GPS/source-metadata preservation, and required foreground precise-location camera authorization approved — 2026-07-26; implementation, disclosure, and device verification remain pending.

### Non-blocking open questions

1. What business model and first launch audience are intended?
2. Which hosting provider and deployment topology should run the NestJS API, PostgreSQL, and Redis?
3. Should retained photo metadata be visible/searchable in PhotoDome, or only travel with the downloaded master?

## Related

- [[PhotoDome]]
- [[2026-07-25 Product Walkthrough]]
- [[2026-07-28 Live Take-Home Availability Decision]]
- [[Media Upload and Retention]]
- [[Architecture and Implementation Plan v0]]
- the foodapp "Meal Lifecycle PRD" (external note, not included in this repo)
- [[Design Spec Rules]]

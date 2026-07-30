---
type: reference
status: shipped
updated: 2026-07-28
---
# M3 Camera and Live Activity

M3 is complete locally in this repository. A live event starts an event-scoped Live Activity whose visible Lock Screen and Dynamic Island surfaces route directly into a one-shutter native camera. A successful shutter press saves the new capture to Photos, queues it into the durable M2 event upload pipeline, and returns to the event without a separate review or confirmation screen. ActivityKit denial, unavailable camera hardware, and absent APNs credentials do not block the event or album.

## Shipped user flow

1. Creating, joining, restoring, or refreshing a `LIVE` event starts or updates its Live Activity when the device allows Live Activities.
2. The Lock Screen surface uses a large monochrome card with a bold event name, compact `LIVE EVENT · N PHOTOS` status, oversized camera cue, and full-width “Take a photo” action. Tapping either the card or its camera action opens that event's camera directly. Expanded, compact, and minimal Dynamic Island presentations use the same capture destination.
3. The capture deep link is `photodome://event/<event-id>/capture`. It contains only the event UUID. The app waits for local event restoration, then resolves the capability from its iCloud Keychain record, so no capability, invite, GCS session, or signed URL enters the Live Activity.
4. The app-owned camera preview opens on the best available rear camera after foreground precise location is authorized and a fresh full-accuracy coordinate is available. It exposes front/back switching, visible Off/Auto/On hardware flash when supported, tap-to-focus/exposure, continuous pinch zoom, and accessible device-aware presets such as 0.5×/1×/2×/5× when those ranges and lens transitions are available. Front preview/capture is mirrored. One shutter press captures the photo using the selected supported flash mode. There is no Retake/Use Photo confirmation and no caption, editing, or posting form.
5. On successful capture, PhotoDome embeds the shutter-time coordinate and capture date in one full-resolution high-quality master, saves that same prepared master to the user's Photos library, admits it into the protected background upload queue, dismisses the camera, and exposes upload/processing progress in the album.
6. Repeated taps on the same Live Activity create distinct presentation requests, so the camera reopens after every completed capture even if the app remains on the same event route.
7. The album retains its multi-select PhotoKit import, upload progress, processing, and retry flow.
8. If camera or precise-location permission is denied/restricted, precise accuracy is disabled, or camera hardware/configuration is unavailable, the capture surface explains the condition, links to Settings when applicable, and allows a PhotoKit selection instead. A capture failure stays on the camera with Try again and Cancel actions.
9. If Live Activities are disabled or ActivityKit refuses a request, the app silently keeps the complete in-app event, camera, import, upload, and album experience.

## Interaction budget

| Starting point | PhotoDome interactions | Result |
|---|---:|---|
| Lock Screen Live Activity | 1. Tap the activity. 2. Tap the shutter. | Photo is saved locally, queued for the event, and the camera closes. |
| Dynamic Island Live Activity | 1. Tap/expand the activity. 2. Tap the capture surface or shutter as presented by iOS. | Camera opens for the correct event and one shutter completes the app flow. |
| Open event album | 1. Tap Camera. 2. Tap the shutter. | Same automatic save-and-share pipeline. |

iOS may require Face ID, passcode, or an unlock transition before showing an
app camera from the Lock Screen. That operating-system security step is outside
PhotoDome's UI and still requires physical-device timing proof.

## Lock Screen presentation

The activity borrows the useful hierarchy of a large status card without
copying another product's branding. PhotoDome keeps its approved white
background, black actions, rounded SF typography, 16-point inset, 12-point
control radius, and 44-point minimum action height.

The top row gives the event name most of the visual weight and places a
56-point black camera circle on the right as an immediate capture cue. The
bottom row is a full-width labeled action rather than an icon-only control, so
the destination remains obvious at a glance and to VoiceOver. The entire live
surface and the labeled action share the same capability-free capture URL.

No progress bar is shown. The Live Activity state has an authoritative photo
count, but no honest duration, completion target, or upload aggregate; drawing
a Tesla-like progress bar would imply progress data PhotoDome does not have. A
brief ended state changes the action to “View event” and routes to the album
instead of offering capture while ActivityKit termination completes.

## Automatic capture pipeline

```text
Live Activity or album Camera
  -> capability-free event capture route
  -> wait for Keychain event restoration
  -> validate local event access and upload admission state
  -> require foreground precise location and a fresh coordinate
  -> rear-camera preview with front/back, flash, focus, and zoom controls
  -> one shutter press
  -> embed shutter-time GPS and capture date once
  -> save the prepared full-resolution master to Apple Photos
  -> persist reservation/file intent in the background upload queue
  -> direct resumable GCS upload
  -> backend verification and variant processing
  -> READY publication to the shared album
  -> Socket.IO foreground update + optional ActivityKit APNs count update
```

PhotoDome does not silently capture from the Lock Screen. The person must see
the camera preview and press the shutter; this preserves explicit camera intent
while removing every app-owned confirmation after the shutter.

## Live Activity lifecycle

- An ActivityKit activity exists only for a locally known event whose current snapshot is `LIVE`.
- The iOS manager restores activity handles after relaunch, starts missing live activities, applies local READY-count updates, observes ActivityKit push-token rotation, and ends an activity immediately after the app observes a non-`LIVE` event state.
- The initial count comes from the event snapshot. Realtime album refreshes use the album page's authoritative `readyPhotoCount`, not the number of thumbnails in the current cursor page.
- The widget and app share `EventActivityAttributes`; APNs `content-state` keys are exactly `photoCount` and `eventHasEnded`.
- M4 now supplies the host-end mutation and remote APNs `end` fan-out described in [[M4 Host Lifecycle and Moderation]]. M3's local non-live reconciliation remains the device-side fallback.

## Backend implementation

### Token registration

`POST /v1/events/:eventId/live-activity-token` registers the current ActivityKit per-activity push token for the authenticated event member. The route:

- requires the event bearer capability;
- accepts only a bounded hexadecimal token;
- replaces the member's prior token so ActivityKit rotation is idempotent;
- never returns or logs the token; and
- stores it on `event_members.live_activity_token`, which is removed with event-member metadata.

The token is a delivery secret. Pino redaction covers `pushToken`, and active-target queries exclude removed members and non-`LIVE` events.

### READY-count updates

After Sharp processing marks a photo `READY`, the worker:

1. emits the existing authenticated `event.photo_ready` Socket.IO message;
2. counts all READY photos for the event;
3. sends an ActivityKit update to every current event-member activity token; and
4. clears tokens Apple reports as unregistered or invalid.

APNs delivery is deliberately fire-and-forget relative to media processing. An Apple outage or invalid token cannot turn a successfully processed photo into `FAILED`.

### APNs configuration

Remote updates use Apple's token-authenticated HTTP/2 provider API and the topic:

`com.younger7jp.photodome.push-type.liveactivity`

Configuration is optional but all-or-none:

- `APNS_ENVIRONMENT=sandbox|production`
- `APNS_BUNDLE_ID`
- `APNS_TEAM_ID`
- `APNS_KEY_ID`
- `APNS_PRIVATE_KEY`

When the four credentials are absent, startup reports that remote Live Activity updates are disabled and the gateway becomes a no-op. Partial credentials fail environment validation. No Apple credential is stored in the repository or vault.

## iOS implementation

- `EventCameraView` owns a portrait `AVCaptureSession`, best-available rear
  virtual camera with front-camera switching, an `AVCapturePhotoOutput`, visible
  Off/Auto/On flash, tap focus/exposure, bounded pinch and discrete accessible
  zoom derived from the active device's minimum and virtual-camera switch-over
  factors, mirrored front preview/output, one accessible shutter,
  authorization, Settings recovery, simulator/no-camera fallback, capture
  retry, and PhotoKit fallback. Configuration and capture exclusion run on the
  serial session queue.
- `EventDeepLink` strictly parses the `photodome://event` routes and rejects malformed or non-UUID event targets.
- `ContentView` waits for any in-flight event restoration before routing. A camera route for an unknown event is refused rather than attempting an implicit join, and each valid capture URL produces a new request so repeat taps reopen the camera.
- `EventLiveActivityManager` owns all ActivityKit request/update/end and rotating-token observation.
- `EventLiveActivityWidget` renders the large monochrome Lock Screen hierarchy and routes its live Lock Screen and Dynamic Island surfaces and explicit camera affordances to the same capture destination. Its transient ended state routes to the event instead.
- The app has the custom URL scheme, camera privacy copy, Live Activity declaration, and development APNs entitlement required for signed device builds.
- Existing M0–M2 Keychain snapshots remain decodable when they predate `readyPhotoCount`.

## Verification completed on 2026-07-25

Backend:

- Prettier, ESLint, production compilation, and production dependency audit passed; the production audit reports zero vulnerabilities.
- Five unit tests passed.
- Six PostgreSQL/Redis/GCS-backed E2E tests passed.
- Coverage includes event-capability enforcement, token validation and rotation, exact ActivityKit content-state generation, invalid-token cleanup, authoritative count output, and the existing upload-to-READY/Socket.IO path.

iOS:

- Swift formatting/lint, widget/app compilation, and signed simulator tests passed.
- The standard scheme reports 9 passed and 3 intentionally skipped live-API tests.
- The live integration scheme reports 12 passed and 0 failed against local NestJS, PostgreSQL, Redis, and GCS.
- Tests prove capability-free event/capture route round trips, reject malformed routes, call the generated token-registration operation, and preserve all M0–M2 integration behavior.

## Streamlining verification completed on 2026-07-26

- Swift format/lint and app-icon validation pass.
- The ActivityKit attribute test proves the capture URL maps to the exact capability-free camera route with no query payload.
- The complete simulator scheme passes 21 unit tests with 5 live-API tests intentionally skipped and all 6 automated accessibility UI tests.
- The app and Live Activity extension compile with the app-owned AVFoundation camera, repeat-presentation request, and serialized cold-start restoration changes.
- The large Lock Screen card, live capture destination, and ended-state album destination compile together in the ActivityKit extension.
- The simulator cannot exercise camera hardware, Lock Screen authentication, flash, or real Live Activity taps; those remain named physical-device gates below.

## Camera-control regression verification on 2026-07-28

- The camera-control baseline shipped to `main` through PR #11.
- Strict Swift format/lint and app-icon validation pass.
- All 46 signed unit tests run with zero failures and five expected opt-in
  live-API skips, including the camera flash and zoom policies.
- The focused production-overlay UI regression passes on an iPhone 17 / iOS
  26.5 simulator, covering visible flash state, 1×/2× zoom, front/back
  switching, front-camera flash unavailability, and shutter availability.
- The unsigned Release simulator build succeeds.
- Real lens selection, flash firing, focus/exposure, mirroring, zoom
  transitions, and capture quality remain in the physical-device gates below.

## Physical-device and Apple-environment validation still required

M3 is shipped locally, but these release gates cannot be proven by the simulator-only environment:

- camera permission allow/deny/re-enable and capture quality on a physical iPhone;
- rear/front input switching, mirrored front capture, Off/Auto/On hardware
  flash, tap focus/exposure, pinch zoom, and optical lens transitions on a
  physical multi-camera iPhone;
- the stated no-more-than-two-interaction Lock Screen-to-camera path on a locked physical device;
- Live Activity disabled behavior on a physical device;
- push-token rotation and remote READY-count delivery through configured sandbox APNs;
- two-iPhone count updates while the receiving app is suspended or terminated;
- signed development and distribution provisioning for the APNs entitlement;
- remote activity termination on host end through configured sandbox APNs; the M4 mutation and APNs `end` path are implemented, but physical-device delivery is not yet proven.

## Build 3 device-aware lens refinement on 2026-07-28

- PR #19 replaced the hard-coded 1×/2× button with presets derived from
  `minAvailableVideoZoomFactor`,
  `displayVideoZoomFactorMultiplier`, and the virtual camera's physical-lens
  switch-over factors.
- The preset row retains a supported 2× crop, adapts when switching to simpler
  front-camera hardware, ramps smoothly between selected presets, and leaves
  continuous pinch zoom intact.
- Strict Swift format/lint, app-icon and Release-configuration validation, all
  59 unit tests with five expected live-API skips, all 17 UI tests, and the
  signed generic-device Release build pass.
- `project.yml` is set to `0.1.0 (3)`, XcodeGen regenerated the project, and
  the built app and Live Activity extension both report build 3.
- A physical multi-camera iPhone must still confirm the reported preset row and
  real optical constituent transitions before the camera defect moves from
  `fixed-pending-verification` to `fixed`.

## Related

- [[Architecture and Implementation Plan v0]]
- [[M2 Direct Upload and Live Album]]
- [[Media Upload and Retention]]

---
type: reference
status: shipped
updated: 2026-07-28
---
# M4 Host Lifecycle and Moderation

M4 is complete locally in this repository. The accountless host can now end an event, optionally restrict new post-end uploads, remove attendees, and rotate the join code with realtime propagation. Each contributor can delete their own ready photos. The implementation preserves already-admitted uploads across the restriction cutoff and terminates Live Activities when the host ends the event.

## Shipped lifecycle

1. `POST /v1/events/:eventId/end` changes a `LIVE` event to `ENDED`.
2. The first successful end stores immutable `endedAt` and `expiresAt = endedAt + 7 days`. Repeating the request returns the original timestamps.
3. Ending does not close uploads. Members can create new reservations after ending until the host explicitly restricts them.
4. `POST /v1/events/:eventId/restrict-uploads` is available only after ending and stores the first `uploadsRestrictedAt`.
5. Restriction blocks new reservations, but a reservation committed before the cutoff can renew its GCS resumable session and complete afterward.
6. M4 records the authoritative expiry clock; the whole-event purge built afterward is documented in [[M6 Expiry Security and Scale]].

Event end and upload restriction use PostgreSQL serializable transactions with bounded conflict retries. Reservation and restriction therefore have one committed order: either the reservation wins and remains usable, or restriction wins and the new reservation is rejected.

## Host moderation

### Attendees

`GET /v1/events/:eventId/members` returns active anonymous member records to the host. On iOS, the host taps the event summary's **N attending** control to open a dedicated attendee sheet. The sheet includes the current host as a non-removable row and exposes a confirmed **Remove** action only for guest rows. Guests see the attendee count but cannot open this host-management surface.

`DELETE /v1/events/:eventId/members/:memberId`:

- can target an active guest but not the host;
- stores `removedAt` and clears that member's Live Activity token;
- makes the capability fail immediately on REST;
- emits `event.member_removed`; and
- disconnects every socket authenticated as that event member.

The removed iPhone deletes its local event capability after the forced socket disconnect or the next authoritative REST rejection.

### Contributor-owned photos

`DELETE /v1/events/:eventId/photos/:photoId` accepts only the capability belonging to the member who contributed the currently `READY` photo. Host status does not grant deletion access to another member's photo. It:

1. changes the photo to `REMOVED` in the database, so album reads hide it immediately;
2. creates a deletion tombstone containing the original, display, and thumbnail object keys;
3. emits `event.photo_removed`;
4. enqueues retryable object deletion; and
5. deletes the database photo row and tombstone only after GCS reports that all three exact objects are absent.

Deletion retries use exponential backoff. A failed attempt retains the keys, attempt count, last error, and photo row, avoiding an orphaned GCS object whose key has already been discarded.

## Realtime contract

Authenticated event sockets now receive:

- `event.member_joined`
- `event.member_removed`
- `event.photo_ready`
- `event.photo_removed`
- `event.ended`
- `event.uploads_restricted`
- `event.code_rotated`

Payloads contain event/member/photo identifiers only. `event.code_rotated` includes the acting member ID so the initiating host device keeps its newly returned code while another restored host surface clears a stale code. REST snapshots remain authoritative; realtime messages only accelerate refresh.

## Live Activity end behavior

Host end sends an ActivityKit APNs `end` event to every stored token for the ended event. Its final content state uses:

- `photoCount`: authoritative READY count;
- `eventHasEnded`: `true`; and
- immediate `dismissal-date`.

Accepted or invalid tokens are cleared. Transiently failed tokens remain stored so an idempotent repeated host-end request can retry them. Independently, any iPhone that observes the `ENDED` snapshot ends its local Live Activity immediately.

APNs delivery still requires the optional credentials documented in [[M3 Camera and Live Activity]]. Without them, local lifecycle and every in-app control continue to work.

## iOS behavior

- The host event screen confirms destructive end, restriction, and attendee removal actions. Tapping **N attending** opens the attendee sheet; the host is identified but cannot be removed, while every active guest exposes a Remove action. Photo deletion is contributor-owned for hosts and guests alike.
- Each action-specific confirmation is attached to the exact visible trigger:
  **Rotate join code**, **End event**, **Restrict new uploads**, the selected
  attendee row's **Remove**, or the selected album photo. SwiftUI can adapt the
  popup above or below that source to fit the screen, but scrolling to a lower
  control no longer reuses the event screen's top/root as its source. App-level
  error alerts remain screen-modal. See [[2026-07-28 Action confirmation – tap
  lower source – warning stays anchored near top]].
- The ended summary shows whether uploads remain open and the seven-day expiry time in the iPhone's current timezone, identified by a friendly localized name or `local time` rather than a numeric GMT/UTC offset.
- New camera and PhotoKit buttons remain available after ending while uploads are open.
- After restriction, those new-admission buttons disable, but the durable M2 queue continues existing upload, verification, processing, and reservation-renewal retries.
- Host attendee management lists the host plus active anonymous guests in a dedicated sheet and refreshes on open, pull-to-refresh, and member realtime messages.
- Long-pressing a member's own ready album photo offers a confirmed **Delete** action. Other members' photos never expose deletion. Every attendee drops a deleted photo immediately on `event.photo_removed` and then refreshes the authoritative album.
- Event end and restriction messages refresh the event snapshot; host end also reconciles and ends the local Live Activity.
- Join-code rotation from another host surface clears a locally cached stale code without exposing the replacement over Socket.IO.

## Verification completed on 2026-07-25

Backend:

- Prettier, ESLint, NestJS production compilation, and six unit tests passed.
- Eight PostgreSQL/Redis/GCS-backed E2E tests passed.
- Repeated concurrent restriction/reservation tests prove that no admitted reservation is cancelled and no new post-cutoff reservation succeeds.
- E2E coverage also proves immutable seven-day timestamps, open uploads after ending, renewal after restriction, host-only lifecycle controls, guest revocation, contributor-only photo deletion, immediate album hiding, Socket.IO photo removal, and verified deletion of all three GCS objects.
- Unit coverage proves the exact final ActivityKit state and retention of transient APNs failures for retry.

iOS:

- App, widget extension, generated client, and signed simulator tests compile and pass under Swift 6.
- The standard scheme reports 9 passed and 4 intentionally skipped live-API tests.
- The live integration scheme reports 13 passed and 0 failed against local NestJS, PostgreSQL, Redis, and GCS.
- Live integration proves end, post-end admission, restriction, grandfathered renewal, post-cutoff rejection, member listing/removal/revocation, contributor-owned ready-photo deletion, and all prior M0–M3 client behavior.
- 2026-07-28 attendee-sheet regression: strict Swift formatting/lint and the Release simulator build passed; the non-flaky scheme executed 38 unit tests with zero failures and five expected opt-in integration skips, plus 10 UI tests with zero failures. Focused policy tests prove only hosts can open management, guests cannot remove anyone, and hosts cannot remove the host row. The UI regression proves **N attending** opens the sheet with one protected host row and a guest Remove action.

The attendee-sheet UX shipped in PhotoDome PR #6 as `0ae4576`.

The source-anchored lifecycle and attendee confirmations shipped in PhotoDome
PR #10 as `7e03bd2`; the lower-row UI regression, signed unit suite, strict
lint, and Release simulator build pass.

## Release validation still required

- Two physical iPhones must prove forced attendee socket revocation, simultaneous host/guest lifecycle refresh, and local cache disappearance.
- A physical iPhone with configured sandbox APNs must prove remote Live Activity termination while the receiving app is suspended or terminated.
- Background restriction tests must be repeated on device under weak connectivity and app termination.
- Production GCS, API hosting, deployment, monitoring, and credentials remain TBD.
- Whole-event cleanup at `expiresAt` is now implemented and destructively proven in [[M6 Expiry Security and Scale]].

## Related

- [[Architecture and Implementation Plan v0]]
- [[M2 Direct Upload and Live Album]]
- [[M3 Camera and Live Activity]]
- [[Media Upload and Retention]]

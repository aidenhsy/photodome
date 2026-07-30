---
type: reference
status: shipped
updated: 2026-07-28
---
# M5 Personal Curation and Download

M5 is complete locally in this repository. During a live event and throughout its unexpired post-end window, each attendee can privately review the ready album, swipe right to keep or left to skip, undo the latest decision, and save either every currently ready photo or only that attendee's kept set to Apple Photos.

## Shipped curation contract

Personal curation is available while an event is `LIVE` or `ENDED` before its seven-day `expiresAt`. The capability guard resolves the active anonymous event member, and every selection is stored against that member. Hosts and guests use the same private attendee behavior; the shared album never changes when somebody keeps or skips a photo.

The API exposes:

- `GET /v1/events/:eventId/selections/review` for a paginated queue of ready photos that the current member has not decided;
- `PUT /v1/events/:eventId/selections/:photoId` with `KEEP` or `SKIP`;
- `DELETE /v1/events/:eventId/selections/latest` to remove that member's latest still-relevant decision; and
- `GET /v1/events/:eventId/download-manifest?mode=ALL|KEPT` for paginated, short-lived signed original URLs.

The review response includes authoritative ready, decided, and kept counts. Repeating a selection for the same member/photo updates the existing private decision rather than creating duplicates. `KEEP` and `SKIP` rows are never returned to another attendee.

Only `READY` photos appear in review queues or download manifests. A host-removed photo immediately disappears from unreviewed queues and from manifests that have not yet been downloaded.

## iPhone review behavior

- During a live event, hosts and guests see **Choose photos** and **Save current photos** directly as soon as the album contains one ready contribution. “Current” communicates that more photos may arrive.
- After ending, the same controls remain available and the bulk action becomes **Save all**. Active, saved, or failed download status follows the actions when present; there is no instructional card or repeated expiry explanation.
- The two take-home controls remain in one horizontal row. Their complete
  labels drop their decorative icons first and then scale on narrower widths
  instead of wrapping to a second line; their accessibility labels retain the
  complete wording.
- The take-home actions stay hidden when the event has zero ready photos and while the event is `EXPIRING`.
- Photos contributed by the current event member are omitted from both the private review queue and download manifests because their source is already in that member's library. New in-app camera captures are saved to Photos before their event upload is reserved.
- Successfully downloaded photo IDs remain in the protected local download record. They are omitted from subsequent review presentation and repeated save actions, while the album marks current-member contributions as **Yours** and completed downloads as **Saved**.
- On a live or ended album, the entire tile for an unsaved photo contributed by somebody else is a download target for both hosts and guests; the arrow remains as its visual cue and becomes an in-progress indicator before the **Saved** badge appears. Tapping a **Saved** or **Yours** tile requires confirmation that another Photos-library copy will be created. Long-press exposes the same download behavior plus **Delete** only for the viewer's own contribution. Explicit single-photo downloads may include the viewer's own contribution, while bulk saving continues to exclude it.
- Repeat-download and photo-deletion confirmations are owned by the exact album
  cell that opened them, with the active presentation scoped by photo ID.
  SwiftUI therefore receives the selected tile's source geometry even after the
  user scrolls deep into the grid. Its adaptive placement may be above or below
  the tile depending on available space. See [[2026-07-28 Action confirmation
  – tap lower source – warning stays anchored near top]].
- The review screen uses a card gesture: right is Keep and left is Skip. Explicit buttons expose the same actions for accessibility. The same private review behavior is available during live and ended states.
- Each decision advances to the next prefetched card immediately while the
  backend write completes. A failed write restores the previous card and its
  reviewed/kept counts.
- Undo removes the latest private decision and restores the photo to the review queue.
- The screen paginates automatically and displays server-derived reviewed and kept counts.
- A new `event.photo_ready` signal refreshes the remaining queue and shows an incoming-photo notice without erasing prior decisions.
- An `event.photo_removed` signal removes the card and cancels any not-yet-saved download for that photo.
- If a five-minute display URL expires during a long review, the screen
  automatically requests a fresh queue page and signed URL.

Album thumbnails and review cards now share the protected Kingfisher path in
[[Local-First Event Media Cache]]. Review prefetches the next four 1,280 px
display variants, and stable cache identity lets a fresh signed credential
reuse an already-downloaded bitmap.

The live album also treats `urlsExpireAt` as part of the media contract. When
the app becomes active within 30 seconds of the earliest album URL expiry, it
refreshes the album page before rendering additional lazy rows. If a current
thumbnail URL still fails, that exact failure triggers one coalesced page
refresh; callbacks for URLs already replaced by the refresh are ignored. This
keeps long-open albums from showing intact private media as gray placeholders
without creating one API request per failed grid cell. See [[2026-07-27 Event
album – scroll or return after signed URL expiry – photos show gray
placeholders]].

## Original download and Photos behavior

The app first resolves the complete paginated manifest for `ALL` or the current member's `KEPT` set. It then persists one queue item per original and uses a background `URLSession` with at most three concurrent downloads.

Each item records queued, downloading, adding-to-Photos, saved, or failed state with byte progress and retry count. The queue and signed manifest state use iOS complete-until-first-unlock file protection and are restored at app launch. Saved rows prevent a repeated Save action from duplicating the same event photo.

When a signed original URL expires, Retry requests a fresh manifest before restarting that photo. A downloaded local file is retained if Photos add-only permission is denied, so the attendee can enable permission in Settings and retry without losing the selected set or redownloading the original. Successfully saved temporary files are removed.

PhotoDome asks only for add-only Photos permission when saving. `PHAssetCreationRequest` receives the server-stored capture date, while the downloaded full-resolution master itself retains the embedded GPS and other source metadata preserved by M2. Display and thumbnail variants remain metadata-free.

The background download delegate synchronously moves each completed URLSession temporary file into protected application storage before returning. This is required because iOS deletes the delegate-provided URL immediately after the callback; the previous asynchronous handoff caused every completed original to fail before Photos authorization or saving began. Retry refreshes the signed URL and now re-enters the corrected path.

Album photo buttons use a shared rectangular interaction shape in addition to
visually clipping their `scaledToFill` thumbnails. Visual clipping alone does
not constrain SwiftUI hit testing, so an oversized thumbnail interaction region
could otherwise cross a grid-row boundary and make a neighboring photo handle
the tap. A Debug-only two-row UI regression taps both sides of the shared edge
and verifies that the visible tile's photo ID receives each action. See
[[2026-07-27 Event album – tap photo near grid-row edge – neighboring photo starts downloading]].

When authoritative access is revoked or an expired event is forgotten, the iPhone cancels that event's active downloads, removes its pending local files and signed URLs, and deletes the local event capability.

## Privacy and logging

- Selection reads and writes are scoped to the current member resolved from the event capability.
- Download manifests are generated on demand and contain only short-lived private GCS read URLs.
- `KEPT` manifests cannot reveal another member's kept set.
- API log redaction includes capabilities, join/transfer tokens, upload sessions, display/thumbnail URLs, and original URLs.
- Original bytes continue to travel directly between the iPhone and private GCS rather than through NestJS.

## Verification

Backend:

- Prettier, ESLint, NestJS production compilation, and six unit tests passed.
- Nine PostgreSQL/Redis/GCS-backed E2E tests passed.
- M5 E2E coverage proves live hosts and guests can use eligible take-home manifests, live guests can privately review and keep photos, two guests can keep different private sets, review counts and pending queues remain private, `ALL` and `KEPT` manifests are correct, signed originals are readable, Undo restores the latest photo, and removed photos are excluded.

iOS:

- SwiftFormat, SwiftLint, app/widget compilation, and the signed simulator suite passed under Swift 6.
- The standard scheme reports 10 passed and five intentionally skipped live-API tests.
- The live integration scheme reports five client/server tests passed and zero failed against local NestJS, PostgreSQL, Redis, and the GCS emulator.
- The M5 integration scenario proves a live guest can review, keep, and bulk-save currently ready photos, then ends the event, gives two guests opposite selections, proves distinct private kept manifests, downloads signed originals, and proves Undo restores the latest skipped photo.
- Queue persistence has unit coverage for signed URL, local-file, task, progress, retry, and failure state.

## Release validation still required

- A physical iPhone must prove add-only Photos authorization, denial → Settings → retry, preserved capture dates, normalized orientation, and visual source quality.
- Background downloads must be interrupted and restored under termination, weak connectivity, and expired signed URLs on a real device.
- A multi-device run must prove incoming-photo insertion and host removal while both attendees are actively reviewing/downloading.
- Authoritative expiry cleanup and its all-generation/server-metadata proof are now shipped in [[M6 Expiry Security and Scale]].
- Production GCS, API hosting, deployment, monitoring, and credentials remain TBD.

The source-anchored album delete/re-download confirmations shipped in PhotoDome
PR #10 as `7e03bd2`; the lower-row UI regression, signed unit suite, strict
lint, and Release simulator build pass. Physical-device source placement remains
part of Build 2 validation.

## Related

- [[Architecture and Implementation Plan v0]]
- [[2026-07-28 Live Take-Home Availability Decision]]
- [[Product Discovery Brief]]
- [[Media Upload and Retention]]
- [[M2 Direct Upload and Live Album]]
- [[M4 Host Lifecycle and Moderation]]

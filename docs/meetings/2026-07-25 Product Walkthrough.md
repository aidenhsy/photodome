---
type: meeting
tag: discovery
status: complete
updated: 2026-07-26
---
# 2026-07-25 Product Walkthrough

> Historical note: the 2026-07-25 decision to strip GPS/sensitive EXIF was
> superseded on 2026-07-26 by [[2026-07-26 Media Fidelity Decision]]. This file
> keeps the original walkthrough intact; current intended behavior lives in the
> product and media specs.

**Project:** [[PhotoDome]]  
**Purpose:** Capture what the app does in the founder's own words, separate confirmed decisions from assumptions, and identify the smallest useful product to build.

## 30-second pitch

> PhotoDome is event photo sharing. For example, James creates an album for his birthday party and shares its QR code or join code. Guests join the live session, view and contribute photos throughout the event, then save either the complete album or only the photos they choose with a Tinder-style left/right swipe.

- **What is PhotoDome?** A live, shared photo album for an event.
- **Who is it for?** Event hosts and the people attending their events.
- **What problem does it solve?** Photos from one event are normally fragmented across many people's phones and difficult to collect or distribute afterward.
- **What is the main thing a user does in it?** Join an event, see and contribute photos live, then take home the photos they want.
- **What is distinctive?** QR/code joining, Lock Screen capture through a Live Activity, and a fast personal swipe-to-keep flow after the event.

## Origin and intent

- Example use case: James's birthday party.
- Product name status: PhotoDome began as the working name and was confirmed as the final product name on 2026-07-25.
- Is this a business, personal tool, experiment, portfolio project, or something else?
- What should be true for this project to feel successful?

## Users and problem

| Question | Notes |
|---|---|
| Primary user | Event attendee who wants to contribute, see, and save the event's photos |
| Secondary users | Event host/organizer who creates and shares the event |
| Buyer / decision-maker | TBD |
| Problem experienced today | An event's photos are fragmented across attendees' camera rolls and are cumbersome to collect, view, and redistribute |
| Current workaround | Group chats, shared albums, cloud-drive links, AirDrop, or manually asking everyone to send photos — examples inferred, not yet founder-confirmed |
| Frequency and severity | Per event; exact target event frequency and urgency are TBD |
| Why existing tools are insufficient | PhotoDome aims to combine instant joining, live group contribution, Lock Screen capture, and personal post-event selection in one flow |

## Core journey

1. James creates a birthday event without creating an account.
2. PhotoDome generates a QR code and a short join code.
3. James displays or shares either code with guests.
4. A guest scans or enters the code and joins the event session without creating an account.
5. During the event, attendees see the pooled live album and contribute new photos from the camera or camera roll.
6. The active event appears as a Live Activity; an attendee can start a capture from the Lock Screen, following the low-friction interaction used by the foodapp "Meal Lifecycle PRD" (external note, not included in this repo).
7. The host ends the live event; uploads remain open by default, including new post-event uploads and queued uploads that still need to finish.
8. The host may restrict/close uploads after ending.
9. During the seven-day post-event window, each attendee chooses between saving all photos or reviewing the album one photo at a time.
10. In review mode, the attendee swipes right/left to keep or skip photos, then saves the selected set.

## Features mentioned

| Feature or behavior | Priority | Confirmed? | Notes |
|---|---|---|---|
| Host creates an event | Must | Yes | Event becomes the shared photo session. |
| QR code and short join code | Must | Yes | Host can share either route. |
| Attendee joins the event | Must | Yes | Guests do not create accounts. |
| Shared live photo view | Must | Yes | Exact realtime latency is TBD. |
| Take and contribute photos | Must | Yes | New captures join the shared event album. |
| Add photos from camera roll | Must | Yes | Permission and duplicate handling are TBD. |
| iOS Live Activity / Lock Screen capture entry | Must | Yes | Desired interaction precedent is foodapp's live meal session. |
| Save all event photos | Must | Yes | Source-quality originals available during the seven-day window; GPS/sensitive EXIF stripped. |
| Tinder-style swipe review | Must | Yes | Right keeps, left skips, Undo reverses the last choice, and selections are private. |
| Download selected photos | Must | Yes | Destination and background-download behavior are TBD. |
| Accountless host | Must | Yes | Event-scoped host capability stored in iCloud-synchronizable Keychain; one-time transfer QR/deep link when needed. |
| Post-end uploads | Must | Yes | Queued and newly initiated uploads remain allowed after ending by default. |
| Host closes uploads | Must | Yes | Blocks new upload reservations; uploads already reserved/in progress may finish. |
| Seven-day retention | Must | Yes | Photos remain available for seven days after ending, then all originals, variants, and server metadata are permanently deleted from GCS. |

## Content and data

- **Created:** events, event membership, uploaded photos, and each attendee's private keep/skip decisions.
- **Uploaded:** camera captures and selected camera-roll photos.
- **Browsed:** the live pooled event album.
- **Received/saved:** either the whole album or the attendee's selected subset.
- Event photos are retained for seven days after the host ends the event. At expiry, PhotoDome permanently deletes the GCS objects and server metadata. Source-quality originals remain downloadable during that window; capture date/orientation survive while GPS and sensitive EXIF are stripped. Already-downloaded device copies are outside server control.
- Photos may contain faces, children, homes, locations, or private moments; access and retention therefore require explicit product rules.
- Video, captions, reactions, comments, AI features, and existing-data import have not been requested.

## Product surfaces

- The product is iPhone-only and uses a native iOS client, matching foodapp's platform approach.
- Roles confirmed so far: host and attendee.
- Host and guests participate without creating accounts.
- Host creates/shares, ends the live event, restricts uploads, removes photos/attendees, and rotates the join code.
- Host control normally recovers invisibly through an iCloud-synchronizable Keychain capability; deliberate transfer uses a one-time QR/deep link. If iCloud Keychain is unavailable and the original phone is lost, control is not weakened through public join credentials.
- Android and web clients are out of scope.
- Reserved/queued uploads persist and may finish after restriction. Admission behavior for a capture created entirely offline before any server reservation remains TBD.

## Visual direction

- Products or screenshots to use as references: Notion and Stoic.
- Desired mood or brand qualities: calm, minimal, focused, and high-contrast.
- Existing logo, colors, type, or assets: the permanent [[PhotoDome Design System]] uses exact black/white brand primitives, supporting neutrals, SF Rounded product type, full-color event photography, and the approved dome-frame app icon in default, dark, and tinted appearances.
- Must-have screens:
- Behaviors or styles to avoid: copying either reference product's branded assets or exact layouts.

Place media in `../_media/` and link it here.

## Business and launch

- Who pays, if anyone?
- What is the initial market or geography?
- Is there a deadline or launch event?
- What is the distribution plan?
- What metric would show the first version is working?

## Technical constraints

| Topic | Decision / constraint |
|---|---|
| Target platforms | iPhone only; native iOS client |
| Preferred stack | Native Swift/SwiftUI client + NestJS backend, following foodapp's core architecture |
| Existing services or APIs | Mirror foodapp where relevant: ActivityKit, PhotoKit, OpenAPI-generated iOS client, PostgreSQL/Prisma, Redis/BullMQ, Socket.IO, object storage, and Pino logging |
| Authentication | Neither host nor guests create accounts; scoped capabilities live in iCloud-synchronizable Keychain, and host control can move through a one-time transfer QR/deep link |
| Storage | Dedicated private GCS bucket; direct durable upload; permanent originals/variants/metadata cleanup seven days after ending; exact image-quality policy and cost limits are TBD |
| Hosting | TBD |
| Budget | TBD |
| Timeline | TBD |

## Decisions

Record only confirmed decisions here.

| Date | Decision | Why |
|---|---|---|
| 2026-07-25 | Keep the code repository uncommitted to a framework during initial discovery. | The product has not been explained yet. |
| 2026-07-25 | Center the product on a live shared album per event. | This is the core founder-described use case. |
| 2026-07-25 | Let hosts share both a QR code and a short join code. | Guests need a low-friction way to enter the same event. |
| 2026-07-25 | Support both direct capture and camera-roll contribution. | Attendees may take photos inside or outside the app. |
| 2026-07-25 | Make the active event accessible from a Live Activity / Lock Screen. | Capturing should remain quick while the event is happening. |
| 2026-07-25 | Offer save-all and swipe-to-select exits. | Different attendees want either the full memory set or a curated personal subset. |
| 2026-07-25 | Let guests join without creating accounts. | Joining at a live event must stay low-friction. |
| 2026-07-25 | Ship for iPhone only. | Live Activity and the foodapp-native interaction model are central to the product. |
| 2026-07-25 | Use a native iOS client and NestJS backend modeled on foodapp. | Reuse a proven project architecture and operating model. |
| 2026-07-25 | The host ends the event. | The host owns the shared event lifecycle. |
| 2026-07-25 | The host does not need an account. | Event creation must be as low-friction as guest joining. |
| 2026-07-25 | Uploads remain open after the event ends by default. | Queued photos must finish and attendees may continue contributing after the live portion. |
| 2026-07-25 | The host can restrict post-event uploads. | The host controls when further contribution closes. |
| 2026-07-25 | Retain event photos for seven days after ending. | Attendees get a limited window to contribute, curate, and download. |
| 2026-07-25 | Recover host control through an iCloud-synchronizable Keychain capability, with one-time device-transfer QR/deep link. | This keeps the normal path accountless and invisible without letting the public join code become a management credential. |
| 2026-07-25 | Closing uploads does not cancel already-reserved/in-progress uploads. | A host restriction is an admission cutoff, not destructive cancellation. |
| 2026-07-25 | Permanently delete all event objects and server metadata at day seven. | GCS must not accumulate expired media or ongoing storage cost. |
| 2026-07-25 | Require an event name; make cover image and location optional. | Creation stays quick while allowing lightweight event identity. |
| 2026-07-25 | Publish successful uploads immediately; let the host remove photos or attendees and rotate the join code. | The album stays live while the host retains safety/control. |
| 2026-07-25 | Keep events private to valid code/capability holders. | Event photos are private by default. |
| 2026-07-25 | Swipe right to keep, left to skip, with Undo; selections remain private. | The curation gesture is predictable and never changes the shared album. |
| 2026-07-25 | Keep source-quality originals; preserve capture date/orientation and strip GPS/sensitive EXIF. | Downloads retain memory quality without leaking location metadata. |
| 2026-07-25 | Set v1 limits at 100 attendees, 2,000 photos, and 20 MB per original. | Provides an explicit first-release performance and cost envelope. |
| 2026-07-25 | Use a temporary black-and-white visual foundation inspired by Notion and Stoic. | Establishes a coherent low-distraction UI for early milestones without blocking on final branding. |
| 2026-07-25 | Keep PhotoDome as the final name and make the monochrome direction permanent. | The name fits the shared-event concept, and quiet black/white chrome lets members' photos carry the emotion. |

## Confirmed behavior

- Swipe review changes only the attendee's personal download set; it does not delete photos from the shared event.
- Swipe right keeps and swipe left skips; Undo reverses the latest decision.
- Ready contributions appear immediately to event members.
- The host and attendees can all contribute photos.

## Non-blocking open questions

1. What business model and first launch audience are intended?
2. Which hosting provider should run the backend?

## Action items

| Owner | Task | Due |
|---|---|---|
| Codex | Convert confirmed answers into the final MVP scope and [[Architecture and Implementation Plan v0]]. | 2026-07-25 |

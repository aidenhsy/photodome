---
type: index
status: living
updated: 2026-07-28
---
# PhotoDome — project docs

**PhotoDome** is a shared event-photo app with no account requirement for hosts or guests. A host creates an event and shares a QR code or short code; attendees join the live album, contribute photos from the camera or camera roll, and see everyone's photos as the event unfolds. As soon as photos are ready, every participant can save the current set or privately swipe-select without waiting for the host. The host ends the live event, but uploads stay open unless the host restricts them; take-home remains available during the seven-day post-end window.

These docs live in the source repository itself, under `docs/`; the code is in `photodome-api/` and `photodome-ios/` at the repo root. The approved MVP is implemented locally through M6, and the local M7 release-hardening tranche covers production fail-closed configuration, privacy, accessibility, readiness, and archive verification. The API is deployed to production, and `0.1.0 (3)` is uploaded to App Store Connect as the TestFlight candidate; the physical-device proof is tracked in [[Release 0.1.0 (Build 3)]] and the remaining build-independent ASC metadata in [[Release 0.1.0 (Build 1)]].

Plain-Markdown knowledge base, readable in any editor. `[[wikilinks]]` refer to other notes by file name, regardless of folder; opening this `docs/` folder as an Obsidian vault makes them clickable, but Obsidian is optional.

## Start here

1. **[[PhotoDome]]** — the canonical project note and current next actions.
2. **[[2026-07-25 Product Walkthrough]]** — the founder's raw product explanation, confirmed decisions, and unresolved questions.
3. **[[2026-07-26 Media Fidelity Decision]]** — the shipped full-resolution master, embedded-metadata preservation, optimized browsing, and precise-location capture decision.
4. **[[2026-07-28 Dev Port and Navigation Direction Decisions]]** — the local dev API port (3663), the host-transfer share removal, and the standing platform-standard navigation-direction rule.
4. **[[Product Discovery Brief]]** — the emerging MVP definition, flows, acceptance criteria, and technical concerns.
5. **[[Media Upload and Retention]]** — accountless host recovery, direct GCS uploads, image variants, and guaranteed seven-day cleanup.
6. **[[Architecture and Implementation Plan v0]]** — approved system boundaries, modules, contracts, build order, tests, and release gates.
7. **[[PhotoDome Design System]]** — the approved permanent identity, tokens, components, content, photography, and accessibility rules.
8. **[[PhotoDome Design System Reference]]** — the shipped SwiftUI foundation, interactive reference, and implementation gotchas.
9. **[[M0 Development Foundation]]** — the shipped local API/iOS scaffold, exact versions, commands, and current boundaries.
10. **[[M1 Accountless Event Spine]]** — the shipped private event, capability, QR/code join, Keychain recovery, rotation, and host-transfer behavior.
11. **[[M2 Direct Upload and Live Album]]** — the shipped direct upload, background queue, processing, private delivery, and realtime album behavior.
12. **[[Local-First Event Media Cache]]** — the shipped Kingfisher image path, protected album snapshots, stable signed-media cache keys, pagination/prefetch, and privacy eviction behavior.
13. **[[M3 Camera and Live Activity]]** — the shipped native capture, event deep links, ActivityKit lifecycle, token registration, and APNs update path.
14. **[[M4 Host Lifecycle and Moderation]]** — the shipped event end/restriction contract, grandfathered uploads, attendee/photo moderation, realtime revocation, and ActivityKit end path.
15. **[[M5 Personal Curation and Download]]** — the shipped private keep/skip/Undo model, paginated signed-original manifests, and persistent background Photos queue.
16. **[[M6 Expiry Security and Scale]]** — the shipped delayed cleanup, reconciliation, metrics, security controls, destructive all-generation proof, and v1 scale result.
17. **[[M7 Release Checklist]]** — the active local, Apple, production, and physical-device gates for TestFlight.
18. **[[M7 Local Release Hardening]]** — the shipped local production guards, readiness, privacy, accessibility, and unsigned archive behavior.
19. **[[Release Versioning]]** — the durable marketing-version, build-number, TestFlight, patch, and parallel-release policy.
20. **[[GCS Development Bucket Validation]]** — the verified real-GCS bucket controls, signed media lifecycle, cleanup proof, and repeatable command.
21. **[[Server Deployment]]** — the shipped GitHub repo, push-to-main deploy pipeline, and shared-server Docker stack.
22. **[[Deployment & Release]]** — the repository workflow, CI-gated API deploy runbook, release state model, and iOS release procedure.
23. **[[Release 0.1.0 (Build 4)]]** — the single `status: current` release note; [[Release 0.1.0 (Build 3)]] is the uploaded TestFlight candidate, and [[Release 0.1.0 (Build 2)]] and [[Release 0.1.0 (Build 1)]] are the superseded earlier cuts.

## Folder structure

| Folder | Purpose |
|---|---|
| `meetings/` | Dated walkthroughs, raw discovery notes, decisions, and action items. |
| `specs/` | Forward-looking PRDs, design specs, implementation plans, and roadmaps. |
| `reference/` | How shipped features and systems actually work today. |
| `bugs/` | One dated note per confirmed defect, including root cause and resolution. |
| `releases/` | One note per version/build following [[Deployment & Release]]; exactly one has `status: current`. |
| `_media/` | Screenshots, diagrams, recordings, and other project-local evidence. |
| `standards/` | Project-independent authoring standards (design specs, reference docs, bug reports, iOS coding rules) copied in so this repo is self-contained. |

## Current state

- **Stage:** approved MVP; M7 local release hardening implemented, external release gates active
- **Source repository:** this repository (`photodome-api/`, `photodome-ios/`, docs under `docs/`)
- **Implementation:** M0 through M6, the local M7 hardening tranche, and the metadata-preserving precise-location media amendment are shipped; production API is live and TestFlight upload `0.1.0 (3)` is done (2026-07-28, superseding the never-device-passed `0.1.0 (2)` and `0.1.0 (1)`), with the physical-iPhone regression tracked in the Build 3 candidate note and remaining ASC metadata in the Build 1 note
- **Product purpose:** collect an event's photos into one live, shared album and make personal saving effortless afterward
- **Primary users:** event hosts and attendees
- **Identity:** hosts and guests participate without accounts; a first-launch display name is kept on the iPhone and attached to new event memberships so people can recognize one another
- **Core flow:** create → join by QR/code → contribute/view live → save current photos or privately swipe-select → host ends event → late uploads remain allowed unless restricted → save all or continue selection → download
- **Retention:** event photos remain available for seven days after the host ends the event
- **Recovery:** invisible host-capability recovery through iCloud-synchronizable Keychain; one-time transfer QR when moving control intentionally
- **Client:** iPhone-only native iOS app with a Live Activity / Lock Screen capture entry, following the interaction principle used by the foodapp "Meal Lifecycle PRD" (external note, not included in this repo)
- **Backend:** NestJS with the same core architecture and supporting stack as foodapp
- **Media:** private Google Cloud Storage; in-progress uploads finish after restriction; all event objects and server metadata are permanently deleted after seven days
- **GCS validation:** the real `photodome-dev` development bucket passes fail-closed policy, private upload/read, variant, and exact-prefix cleanup verification; production storage remains TBD
- **Moderation/privacy:** private to code holders; host can remove photos/attendees and rotate the code; personal selections stay private
- **Media policy:** the full-resolution downloadable JPEG master retains embedded GPS and source metadata while separate metadata-free display/thumbnail variants keep browsing fast; supported JPEG imports remain byte-for-byte unchanged, other supported stills receive at most one high-quality full-resolution encode, and PhotoDome camera capture requires foreground precise-location authorization and embeds the shutter-time coordinate
- **V1 envelope:** 100 attendees, 2,000 photos, 20 MB per original
- **Brand:** PhotoDome is the final name; its permanent black-and-white design system is implemented in SwiftUI and an interactive reference
- **App icon:** approved default, dark, and tinted 1024×1024 dome-frame assets compile into the Release archive
- **Hosting:** the API deploys from GitHub (`aidenhsy/photodome`) to the shared GCE server on pushes to `main`, mirroring foodapp, and is publicly served at `https://api.kindredarc.com`; see [[Server Deployment]]. The confirmed decision is to keep using the `photodome-dev` GCS bucket
- **Still TBD:** how metadata is surfaced in the UI, supported master formats beyond current JPEG stills, business model/launch audience, first-release languages, crash/alerting provider and owner, and remaining Apple/App Store inputs

## Working rules

- Confirm the remaining privacy, lifecycle, moderation, and scale boundaries before committing to an implementation plan.
- Keep facts, assumptions, decisions, and open questions visibly separate.
- Put intended behavior in `specs/`; move the as-built truth into `reference/` after it ships.
- Attach screenshots and diagrams under `_media/` and link them from the note that explains them.
- Never put secrets, credentials, personal data, or production data in the vault.
- Update this index when a document becomes a recommended starting point.

## Authoring standards

New PRDs and design specs follow [[Design Spec Rules]]. Stable post-build documentation follows [[Reference Doc Rules]]. Confirmed defects follow [[Bug Report Rules]].

## Instructions for future agents

1. Read this `README.md`, [[2026-07-25 Product Walkthrough]], and [[Product Discovery Brief]] before planning or coding.
2. Do not fill a `TBD` with a guess. Record assumptions explicitly and get them confirmed.
3. Use YAML frontmatter with `type`, `status`, and `updated` on every durable project note.
4. Use one H1 per note and only create wikilinks to notes that already exist or are created in the same change.
5. Keep documentation synchronized with implementation, while preserving the distinction between planned and shipped behavior.

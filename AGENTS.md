# PhotoDome agent instructions

## Source of truth

Product documentation lives in this repository at `docs/`.

Before planning or implementing product work, read:

1. `docs/README.md`
2. `docs/meetings/2026-07-25 Product Walkthrough.md`
3. `docs/specs/Product Discovery Brief.md`
4. `docs/specs/Media Upload and Retention.md` before implementing identity, uploads, GCS delivery, image processing, or cleanup
5. `docs/specs/Architecture and Implementation Plan v0.md` before scaffolding or implementing any milestone

## Working rules

- Do not invent product behavior, users, business rules, platform choices, or technical constraints. Mark unknowns as `TBD`.
- Keep raw conversation notes in `docs/meetings/`, planned behavior in `docs/specs/`, shipped behavior in `docs/reference/`, and confirmed defects in `docs/bugs/`.
- When implementation changes the current behavior, update the relevant documentation in `docs/` in the same task.
- Do not describe planned behavior as shipped.
- Keep secrets, credentials, personal data, and production data out of the repository, including `docs/`.
- Store event media in a separate private GCS bucket. Seven days after an event ends, permanently delete its originals, variants, and server metadata; do not discard database object keys before GCS deletion is verified.
- Host upload restriction blocks new reservations but must not cancel uploads that were already reserved/in progress.
- Follow any more specific `AGENTS.md` added later in a subdirectory.

## Repository workflow and releases

- For any CI, environment, deployment, versioning, signing, TestFlight, or release
  work, first read `docs/reference/Deployment & Release.md`.
- Work on short-lived `feat/…`, `fix/…`, `chore/…`, or `docs/…` branches from
  current `origin/main`; never use `main` as the working branch. Open a PR, treat
  CI (`API CI and Deploy` → `verify`) as authoritative, and squash-merge only
  green PRs. Branch protection is unavailable on the current GitHub plan — the
  no-direct-push rule is policy and must be enforced by humans and agents.
- Merging to `main` deploys `photodome-api` to production automatically after a
  green verify. New required environment variables must exist in the server
  `.env` before merge, or startup fails closed.
- Version and build numbers follow `docs/reference/Release Versioning.md` and are
  set only in `photodome-ios/project.yml` (then `xcodegen generate`). Project
  metadata edited directly in the pbxproj or Info.plist is lost on regeneration.
- Exactly one note in `docs/releases/` has `status: current`; rotate it per the
  Deployment & Release runbook after every upload.

## Repository status

This repository was initialized as an empty product workspace on 2026-07-25. The confirmed direction is an iPhone-only native Swift/SwiftUI client with a NestJS backend modeled on foodapp, including its Clean Architecture conventions, PostgreSQL/Prisma persistence, Redis/BullMQ jobs, Socket.IO realtime transport, OpenAPI-generated Swift client, private Google Cloud Storage media flow, and Pino logging. Exact package versions, hosting provider, and deployment process have not been selected.

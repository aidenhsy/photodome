# PhotoDome agent instructions

## Source of truth

Product documentation lives at:

`/Users/aidenyang/Documents/brain/10 Projects/photodome`

Before planning or implementing product work, read:

1. `README.md`
2. `meetings/2026-07-25 Product Walkthrough.md`
3. `specs/Product Discovery Brief.md`
4. `specs/Media Upload and Retention.md` before implementing identity, uploads, GCS delivery, image processing, or cleanup
5. `specs/Architecture and Implementation Plan v0.md` before scaffolding or implementing any milestone

## Working rules

- Do not invent product behavior, users, business rules, platform choices, or technical constraints. Mark unknowns as `TBD`.
- Keep raw conversation notes in `meetings/`, planned behavior in `specs/`, shipped behavior in `reference/`, and confirmed defects in `bugs/`.
- When implementation changes the current behavior, update the relevant vault documentation in the same task.
- Do not describe planned behavior as shipped.
- Keep secrets, credentials, personal data, and production data out of the repository and vault.
- Store event media in a separate private GCS bucket. Seven days after an event ends, permanently delete its originals, variants, and server metadata; do not discard database object keys before GCS deletion is verified.
- Host upload restriction blocks new reservations but must not cancel uploads that were already reserved/in progress.
- Follow any more specific `AGENTS.md` added later in a subdirectory.

## Repository status

This repository was initialized as an empty product workspace on 2026-07-25. The confirmed direction is an iPhone-only native Swift/SwiftUI client with a NestJS backend modeled on foodapp, including its Clean Architecture conventions, PostgreSQL/Prisma persistence, Redis/BullMQ jobs, Socket.IO realtime transport, OpenAPI-generated Swift client, private Google Cloud Storage media flow, and Pino logging. Exact package versions, hosting provider, and deployment process have not been selected.

---
type: reference
status: shipped
updated: 2026-07-25
---
# M0 Development Foundation

M0 is complete in this repository. This note describes only the foundation that exists now. Event creation, accountless capabilities, joining, uploads, realtime albums, host controls, curation, downloads, and cleanup remain planned work in [[Architecture and Implementation Plan v0]].

## What exists

- A parent PhotoDome workspace with `photodome-api/` and `photodome-ios/`.
- A strict TypeScript NestJS API organized with the first Clean Architecture module: `health/domain`, `health/application`, and `health/presentation`.
- `GET /v1/health`, Swagger UI at `/api`, and the OpenAPI JSON document at `/api-json`.
- Environment validation for `NODE_ENV`, `PORT`, `DATABASE_URL`, `REDIS_URL`, logging, and CORS.
- Pino request logging with capability, join-code, upload-session, signed-URL, authorization, and cookie redaction paths prepared.
- Prisma and PostgreSQL foundations without product tables; event/capability schema work starts in M1.
- Redis/BullMQ, Socket.IO, private-GCS library dependencies, and Docker Compose services prepared but not connected to product modules.
- A native SwiftUI iPhone app, unit-test bundle, and embedded ActivityKit/WidgetKit Live Activity extension.
- An offline OpenAPI export and pinned Swift client-generation workflow modeled on foodapp.
- A generated Swift client that calls the local health endpoint through `OpenAPIURLSession`.

## Pinned foundation

| Layer | As-built choice |
|---|---|
| Local Node runtime | Node.js 24.14.1; package requires Node.js 22 or newer |
| API | NestJS 11.1.28, strict TypeScript 5.7.3 |
| Contract | `@nestjs/swagger` 11.4.6 and Swift OpenAPI Generator 1.10.4 |
| Persistence | Prisma 6.19.3; PostgreSQL 17 Alpine in Docker Compose |
| Jobs/realtime | BullMQ 5.78.0, Redis 7 Alpine, Socket.IO 4.8.3 |
| Media library | `@google-cloud/storage` 7.21.0; no bucket or media flow is created in M0 |
| Logging | `nestjs-pino` 4.6.1 and Pino 10.3.1 |
| iOS toolchain | Xcode 26.5, Swift 6 mode, iOS 26.0 deployment target |
| iOS networking | Swift OpenAPI Runtime 1.12.0 and URLSession transport 1.3.0 |
| Project generation | XcodeGen with `photodome-ios/project.yml` as source |
| Local bundle IDs | `com.younger7jp.photodome` and `.live-activity`; provisional until distribution setup |

The exact versions above are implementation facts for M0, not a commitment to keep them forever. Production hosting, deployment, signing team, and final bundle identifiers remain TBD.

## Visual foundation

The temporary visual direction is monochrome: white canvas, black primary text and controls, restrained translucent-black secondary text and hairlines, generous spacing, and rounded system typography. Notion and Stoic are mood references only; their branded assets or layouts are not copied.

This paragraph records the M0 state. The approved permanent identity now lives
in [[PhotoDome Design System]] and its shipped implementation is recorded in
[[PhotoDome Design System Reference]].

The M0 screen is a foundation/health surface, not a proposed product home screen. It shows the working name, a short descriptor, local API state, and a retry action. The Live Activity uses the same black-and-white tokens.

## Local workflow

### API

```bash
cd photodome-api
cp .env.example .env
npm install
npm run prisma:generate
docker compose up -d
npm run start:dev
```

The committed `.env.example` contains local-only development defaults. `.env` is ignored. No GCS credentials or production values belong in either repository or vault.

### Generated iOS client and project

```bash
cd photodome-ios
Scripts/regenerate-api.sh
open PhotoDome.xcodeproj
```

`regenerate-api.sh` builds the Swagger document from the NestJS application without opening a listener, writes the ignored `openapi.json`, regenerates `PhotoDome/Generated/Types.swift` and `Client.swift`, and runs XcodeGen. Generated Swift files are checked in so the app builds from a fresh clone without first running the generator.

### Verification

Backend checks:

```bash
cd photodome-api
npm run format:check
npm run lint
npm test -- --runInBand
npm run test:e2e -- --runInBand
npm run build
npm audit --omit=dev
```

iOS checks use the `PhotoDome` scheme for the app, extension, and unit tests. With the API running locally, the `PhotoDome-Integration` scheme enables the generated-client integration test:

```bash
cd photodome-ios
Scripts/lint.sh
xcodebuild -project PhotoDome.xcodeproj \
  -scheme PhotoDome-Integration \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

On 2026-07-25 the API unit test, API E2E test, TypeScript build, iOS simulator build, monochrome theme unit test, and generated-client-to-live-API integration test all passed. The app was launched on an iPhone 17 Pro simulator and displayed `LOCAL API CONNECTED`.

## Deliberately not implemented

- No event/member/capability database tables or endpoints.
- No Keychain capability recovery or host transfer.
- No QR/code join flow.
- No photo capture, PhotoKit import, GCS bucket, upload reservation, variants, or cleanup worker.
- No Socket.IO event stream or APNs ActivityKit updates.
- No save-all or swipe-selection product UI.
- No production infrastructure, signing, CI, or deployment.

These boundaries prevent the scaffold from being mistaken for a working MVP. The next approved milestone is M1, the accountless event spine.

## Related

- [[Product Discovery Brief]]
- [[Media Upload and Retention]]
- [[Architecture and Implementation Plan v0]]
- [[2026-07-25 Product Walkthrough]]

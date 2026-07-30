---
type: reference
status: active
updated: 2026-07-26
---
# Release Versioning

Reference policy for PhotoDome iOS version numbers, build numbers, beta trains, and parallel maintenance. Use it with [[M7 Release Checklist]] whenever preparing a TestFlight or App Store deployment.

Created 2026-07-26 when the first beta was fixed at version `0.1.0` build `1` and the parallel `0.1.x`/`0.2.0` workflow was confirmed.

## At a glance

PhotoDome uses a SemVer-like `MAJOR.MINOR.PATCH` marketing version and a separate monotonically increasing integer build number. The first TestFlight line is `0.1.0 (1)`. Rebuilt binaries for the same unreleased beta keep `0.1.0` and increase only the build; a shipped `0.1.0` bug fix becomes `0.1.1`; the next feature milestone becomes `0.2.0`. Work may continue on `0.2.0` while supported `0.1.x` bugs are fixed, but every applicable fix must also move forward into `0.2.0`.

## The two numbers

| Value | Xcode setting | Meaning | PhotoDome rule |
|---|---|---|---|
| Marketing version | `MARKETING_VERSION` / `CFBundleShortVersionString` | User-visible release line | Three integers: `MAJOR.MINOR.PATCH` |
| Build number | `CURRENT_PROJECT_VERSION` / `CFBundleVersion` | Exact binary iteration | One globally increasing integer |

The checked-in source of truth is `photodome-ios/project.yml`. XcodeGen applies the same marketing version and build number to the app and Live Activity extension.

## What each version means

- `0.y.z` — pre-1.0 development and beta releases. Product behavior may still evolve.
- `0.1.0` — PhotoDome's first complete end-to-end beta line.
- `0.1.1`, `0.1.2` — released fixes that preserve the `0.1` feature scope.
- `0.2.0` — the next meaningful feature/product milestone. This is a **minor** version, not a major version.
- `1.0.0` — the first public/stable product release when its behavior and operating model are ready for that commitment.

Before `1.0.0`, a substantial or incompatible product/API change normally advances the minor line (`0.1.0` → `0.2.0`). After `1.0.0`, incompatible changes require a major version (`1.x` → `2.0.0`).

## Choosing the next number

| Situation | Next identifier | Reason |
|---|---|---|
| Replace an unreleased/TestFlight `0.1.0` binary | `0.1.0 (2)` | Same beta release, new binary |
| Replace it again | `0.1.0 (3)` | Build increments; marketing version stays |
| Fix a bug after `0.1.0` has shipped as a release | `0.1.1 (next build)` | User-visible backward-compatible patch |
| Add the next planned feature set | `0.2.0 (next build)` | New pre-1.0 minor milestone |
| Make another fix to the shipped `0.1` line while `0.2.0` is in development | `0.1.1` or `0.1.2` | Parallel maintenance is allowed |
| Declare the first stable/public product contract | `1.0.0 (next build)` | First major release |

An iOS-only code change that produces a new uploaded binary always gets a new build number. A compatible backend-only deployment does not require an iOS version bump; it should be identified by its deployment revision/commit once production hosting is selected.

## Parallel `0.1.x` and `0.2.0` work

Maintaining the current release while developing the next minor release is normal:

1. Treat `0.1.x` as the supported release line.
2. Develop the next feature milestone as `0.2.0`.
3. If a user-facing bug affects `0.1.x`, fix and test it on that release line.
4. Release the fix as the next patch, such as `0.1.1`.
5. Forward-port the same fix into `0.2.0` unless the changed feature no longer exists.

When Git release branches are introduced, use `release/0.1` for maintained `0.1.x` fixes and keep the primary development branch moving toward `0.2.0`. Do not let a correction exist only in the old line and silently regress in the next one.

The API must remain compatible with both the current App Store/TestFlight release and the next active beta while both are supported. A backend deployment must not break `0.1.x` merely because `0.2.0` development has started.

## Build-number policy

- Start at build `1`.
- Increase the integer for every archive intended for upload: `1`, `2`, `3`, and so on.
- Never reuse a previously uploaded version/build pair.
- Use one increasing sequence across all PhotoDome marketing versions to avoid collisions and ambiguity.
- A failed local build does not consume a number; an uploaded build does.
- Changing `0.1.0` to `0.1.1` or `0.2.0` does not reset the build number.

Example sequence:

| Purpose | Version shown |
|---|---|
| First TestFlight | `0.1.0 (1)` |
| Beta correction | `0.1.0 (2)` |
| Another beta correction | `0.1.0 (3)` |
| Released-line hotfix | `0.1.1 (4)` |
| Next feature beta | `0.2.0 (5)` |

## Decisions and gotchas

- The App Store marketing version is not the same as the TestFlight build number.
- Do not create `0.1.1` for every pre-release beta correction; keep `0.1.0` and increment the build until a user-visible release needs a patch version.
- Do not describe `0.2.0` as the next major version. It is the next minor line under major version zero.
- Never change the contents of an already released version. Publish a new patch/minor version.
- Forward-port release-line fixes before considering the bug closed.
- Keep API/database migrations compatible with every still-supported app line, or explicitly retire the old line before deploying an incompatible backend.

## Related

- [[M7 Release Checklist]]
- [[M7 Local Release Hardening]]
- [[Architecture and Implementation Plan v0]]
- [[PhotoDome]]
- [[Reference Doc Rules]]

---
type: reference
status: living
updated: 2026-07-28
---
# Deployment & Release

Reference doc + runbook for shipping PhotoDome end-to-end: the repository workflow, the API's CI-gated push-to-deploy pipeline, the release state model, and the iOS archive path. Modeled on foodapp's runbook of the same name, adapted to PhotoDome's simpler single-environment pipeline and to [[Release Versioning]] (which owns the version/build numbering rules). Infrastructure details live in [[Server Deployment]]; the per-release record lives in `releases/` (e.g. [[Release 0.1.0 (Build 1)]]).

Created 2026-07-27 when PR-gated CI was added in front of the existing push-to-main deploy and the release state model was adopted.

## At a glance

1. **API**: open a PR → the `verify` job runs the full check suite → squash-merge to `main` → the same workflow re-verifies and the `deploy` job SSH-deploys the server, which rebuilds from source and health-checks `/v1/health`. Container startup runs `prisma migrate deploy`.
2. **Release states**: exactly one release note in `releases/` has `status: current`. An API deploy plus a TestFlight upload create a `candidate`, never a `shipped`. Rotation is mandatory after every upload.
3. **iOS**: version and build numbers live in `photodome-ios/project.yml` (XcodeGen applies them to the app and the Live Activity extension); archive/upload is CLI-driven once signing exists. Numbering follows [[Release Versioning]]: first line `0.1.0 (1)`, one globally increasing build integer.

## The pieces

| Thing | Value |
|---|---|
| Prod VM | `ssh aidenhsy@34.84.34.186` (docker needs `sudo`) — shared with foodapp and fl-api; their containers are DIFFERENT products, don't touch |
| Containers | `photodome-api`, `photodome-postgres`, `photodome-redis` (`docker-compose.prod.yml` in `/var/www/photodome/photodome-api`) |
| Prod API URL | `https://api.kindredarc.com`; liveness `GET /v1/health`, readiness `GET /v1/health/ready` (both must return **200**) |
| Prod media | private GCS bucket `photodome-prod-younger7` in project `younger7`, location `US`, accessed only by `photodome-media-prod@younger7.iam.gserviceaccount.com`; production must never point at or access `photodome-dev` |
| Dev API | `localhost:3663` against the local compose services (`localhost:4056` on the VM) |
| CI workflow | `.github/workflows/deploy.yml` — jobs `verify` (PRs and pushes) and `deploy` (pushes/dispatch only, needs green verify) |
| App | product "PhotoDome", scheme `PhotoDome`, bundle id `com.younger7jp.photodome`, ASC record "Photodome App" (App Apple ID `6794949795`, SKU `photodome-001`), targets sharing version numbers: app + `PhotoDomeLiveActivity` via the project-wide `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `project.yml` |
| Signing | `DEVELOPMENT_TEAM` is still empty — signing/App Store Connect setup is an open external gate in [[M7 Release Checklist]] |
| Version numbers | `photodome-ios/project.yml` lines `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`; always edit there and regenerate — never in the pbxproj or Info.plist directly |

## Repository workflow and guardrails

Applies to all work in the `photodome` monorepo (API and iOS alike).

| Guardrail | Policy |
|---|---|
| Working branch | Start from current `origin/main`; use a short-lived `feat/…`, `fix/…`, `chore/…`, or `docs/…` branch. Never use `main` as the working branch. |
| Dirty checkout | Existing changes belong to the user; don't reset, stash, or overwrite them — use an isolated worktree from `origin/main`. |
| Integration | Open a PR; CI is authoritative. Merge only green PRs using **squash merge** (merge commits and rebase merges are disabled; merged branches auto-delete). |
| `main` enforcement | Branch protection cannot be enabled (private repo, current GitHub plan) — the no-direct-push and green-PR rules are policy, enforced by humans and agents. |
| Documentation | Update the vault (canonical note + current release note) in the same task as behavior-changing work. |

Bootstrap exception, recorded: the commits that created the repo, pipeline, and this policy itself (2026-07-26/27) were pushed directly to `main`. Everything after adopts the PR path.

## Release state model

Same operational states as foodapp — these words are states, not synonyms:

| State | Meaning | Exit condition |
|---|---|---|
| `current` | Active development scope; changes may still enter the build. | Scope frozen, CI green, API deploy healthy, iOS archive uploaded. |
| `candidate` | Internal TestFlight candidate; closed to new scope. | Required device checks pass, or documented exceptions accepted. |
| `accepted` | Candidate passed release acceptance. | Submitted to App Review. |
| `submitted` | Waiting for App Review/release. | The App Store version is actually released. |
| `shipped` | Released to users; reserved for a production release whose acceptance checks passed. | Terminal for that build. |

**Versioning is [[Release Versioning]]'s job, not this doc's.** In short: release notes are named `Release <MAJOR.MINOR.PATCH> (Build <n>).md`; replacing an unreleased beta binary keeps the marketing version and increments only the build (`0.1.0 (2)`), a shipped-line fix becomes `0.1.1`, the next milestone becomes `0.2.0`, and the build integer increases globally and is never reused. Do not copy foodapp's habit of a two-part marketing version (`1.2`) — PhotoDome always uses three parts.

**After every upload (mandatory rotation):**
1. Set the uploaded note's `status: candidate`, add a `> [!warning] 🟡 CANDIDATE <date>` banner, and record the API commit/run and archive/upload evidence. Keep its verification checklist live.
2. Create the next note per [[Release Versioning]] (same marketing version + next build for another beta iteration; next patch/minor when the line advances) with `status: current` and the 🔵 CURRENT banner.
3. Exactly one note is `current` at any time. Advance candidate → accepted → submitted → shipped only on the real events; an upload date is not a ship date.

## API deploy

**Mechanics.** `.github/workflows/deploy.yml` runs `verify` for every PR and push to `main` that touches `photodome-api/**` (or the workflow itself): compose test services (postgres 17 + redis + fake-gcs) with health-gated `--wait`, `npm ci`, `prisma generate`, `format:check`, `lint`, `build`, unit tests, the five-suite e2e run (whose prepare step applies the full migration chain to a fresh database), and a production `docker build`. On pushes and manual dispatch, `deploy` (gated on green `verify`, serialized by a `deploy-production` concurrency group) SSHes to the VM, hard-resets `/var/www/photodome` to `origin/main`, rebuilds with `docker compose -f docker-compose.prod.yml up -d --build`, and polls `/v1/health` for 60 s, dumping container logs on failure.

Unlike foodapp there is **no staging instance and no immutable registry image** — the server rebuilds from source on each deploy. This is a deliberate simplification for the current single-developer pre-TestFlight stage; adopt foodapp's digest-promotion path if/when a broken deploy would hurt real users.

**Runbook:**
1. Branch from `origin/main`; implement with focused tests; run the narrow checks locally while iterating.
2. Open the PR and let `verify` run. Fix failures on the branch — never bypass by merging or deploying manually.
3. **Any new migration:** validate the full chain against a fresh scratch database first (the e2e prepare step in CI also does this).
4. **NEW REQUIRED ENV VARS → add them to the server `.env` before merge, or startup fails.** `env.validation.ts` throws before Nest starts; production additionally fail-closes on the M7 guards (real GCS only, a media-bucket name that is not marked dev/development, metrics token, non-default pepper, full APNs credentials). Diff against `.env.example`; never print secret values. (foodapp's Build-26 `ADMIN_JWT_SECRET` omission caused a ~6-minute production outage — same failure class applies here.)
5. Squash-merge the green PR, then `gh run watch <id> --exit-status` for the push run: `verify` then `deploy` must both pass.
6. Verify: `GET https://api.kindredarc.com/v1/health` and `/v1/health/ready` both 200; `sudo docker ps` on the VM shows the three containers running.

**Failed migration recovery:** inspect the database state first; `prisma migrate resolve --rolled-back <name>` only marks an already-reverted failed migration. Fix forward, validate the full chain on a fresh database, redeploy through a PR. Never edit an applied migration and never run `prisma migrate dev` against production.

**Bad application code rollback:** there is no prior image to re-pin — revert the commit through a PR (or `git revert` pushed to `main` in an emergency) and let the pipeline redeploy; `workflow_dispatch` re-runs the deploy from current `main`. Schema changes still require forward-compatible repair.

## iOS release

Signing, App Store Connect, and the physical-device pass are still open gates ([[M7 Release Checklist]]); this section records what already holds so the first cut follows it.

**Pre-archive checklist:**
1. Candidate source reached `main` through a green PR and the checkout is clean at that commit.
2. Version and build set in `project.yml` per [[Release Versioning]] (**next global build number; never reuse an uploaded pair**), then `xcodegen generate` — the project is generated, so numbers or Info.plist keys edited anywhere else are silently lost on the next regeneration.
3. Release-configuration build passes: `xcodebuild -project PhotoDome.xcodeproj -scheme PhotoDome -configuration Release -destination generic/platform=iOS build` (redirect to a log file and echo `$?`; don't pipe xcodebuild through `tail`).
4. Release resolves the deployed API automatically — `PHOTODOME_RELEASE_API_BASE_URL` defaults to `https://api.kindredarc.com` in `project.yml`, and the pre-build script plus runtime validation reject non-HTTPS values ([[M7 Local Release Hardening]]).
5. The Live Activity extension is embedded and stamped with the same version/build (project-wide settings make this automatic — verify in the built product's `PlugIns/*.appex/Info.plist` anyway).
6. Backend deployed + verified first when the client needs new endpoints.

**Archive + upload (proven 2026-07-27, 0.1.0 (1)):**

```bash
# 1. Archive (cloud signing; team 35Q36KU73C via project.yml DEVELOPMENT_TEAM)
xcodebuild archive -project PhotoDome.xcodeproj -scheme PhotoDome \
  -destination generic/platform=iOS \
  -archivePath ~/Library/Developer/Xcode/Archives/$(date +%F)/PhotoDome-<ver>-<build>.xcarchive \
  -allowProvisioningUpdates > /tmp/photodome-archive.log 2>&1; echo "EXIT: $?"

# 2. exportOptions.plist
#   method: app-store-connect · destination: upload · signingStyle: automatic
#   teamID: 35Q36KU73C · uploadSymbols: true · manageAppVersionAndBuildNumber: FALSE

# 3. Upload
xcodebuild -exportArchive -archivePath <the .xcarchive> \
  -exportOptionsPlist exportOptions.plist -allowProvisioningUpdates \
  > /tmp/photodome-upload.log 2>&1; echo "EXIT: $?"
# success = "Upload succeeded" + "** EXPORT SUCCEEDED **" in the log
```

The ASC app record is **"Photodome App"** (created manually 2026-07-27; "PhotoDome" was already taken as an App Store name — display name is changeable in ASC until first release, and never affects the bundle id or brand). Uploading without an app record fails with `Error Downloading App Information` / `missingApp(bundleId:)`.

## Decisions & gotchas

- **"Completed processing" ≠ installable.** ASC sends the processing email and even tester invites while the build is held in **Missing Compliance**; the TestFlight app on the phone silently shows nothing installable. Build `0.1.0 (1)` sat in this hold on 2026-07-26 because the binary lacked `ITSAppUsesNonExemptEncryption`. The key is now declared in `project.yml` (`false` — standard HTTPS/TLS only, exempt; PR #2), so future builds skip the question; a held build is released manually in ASC: app → TestFlight → build → Manage next to Missing Compliance → standard/exempt encryption.
- **Certificate expiry cannot break TestFlight.** Apple re-signs TestFlight builds; uploaded builds don't depend on any developer certificate afterward, and cloud signing manages the distribution certificate automatically (expired old certs in the portal are harmless). A 2026-07-26 scare about "expired company certificate" was disproven by evidence: the same-day archive, upload, and processing all succeeded. Diagnose from Apple's actual emails and logs before renewing anything.
- **ASC outages can render an empty apps list.** During a 2026-07-26 Apple incident, ASC showed "Sorry, something went wrong" plus a "You haven't added any apps yet" empty state — a failed-fetch artifact, not data loss. Check https://developer.apple.com/system-status/ before assuming account damage; mobile-web ASC is the flakiest surface.

- **GitHub Actions billing can block all runs** (account-level "payments have failed / spending limit" error, ~3 s failures before any job starts). The deploy script is exactly the workflow's `script:` block and can be run manually over SSH — but `verify` has no manual equivalent shortcut; run the same commands locally before any manual deploy.
- **The deploy paths filter means iOS-only pushes don't deploy** — correct and intended; only `photodome-api/**` and the workflow file trigger the pipeline.
- **`project.yml` is the only safe place for project metadata.** The 2026-07-27 regeneration silently dropped `NSLocationWhenInUseUsageDescription` because it had been added to Info.plist directly. Version numbers, Info.plist keys, build settings — always in `project.yml`, then `xcodegen generate`.
- **CI's fake-gcs is dev-only**: production fail-closes on `GCS_API_ENDPOINT` being empty, so CI results say nothing about real-GCS behavior; [[GCS Development Bucket Validation]] holds the real-bucket proof.
- **Storage environments are hard boundaries.** Production uses
  `photodome-prod-younger7`; `photodome-dev` is only for real-GCS development
  validation. Never run cleanup, verification, tests, or local tooling against
  the production bucket. Production startup rejects bucket names marked
  `dev`/`development`. The production service identity has bucket-scoped access
  to production and receives `403` from the development bucket; the development
  identity has no production-bucket role.
- **`prisma` must stay in `dependencies`** (not dev) — the runtime image prunes devDependencies, and `start:prod` runs `prisma migrate deploy` at container start.
- **The shared VM hosts foodapp and fl-api.** Container lists will show them; leave them alone.

## Related

[[Server Deployment]] (infrastructure as-built) · [[Release Versioning]] (numbering policy) · [[Release 0.1.0 (Build 1)]] (first release note) · [[M7 Release Checklist]] (external gates) · [[M7 Local Release Hardening]] · [[Reference Doc Rules]]

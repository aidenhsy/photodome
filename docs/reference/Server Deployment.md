---
type: reference
status: living
updated: 2026-07-27
---
# Server Deployment

Reference doc for how the PhotoDome API is deployed: the GitHub repository, the push-to-main GitHub Actions pipeline, and the shared GCE server stack, modeled directly on foodapp-api's deploy. Related: [[M7 Release Checklist]] (production gates), [[GCS Development Bucket Validation]] (the bucket this deployment uses), [[M0 Development Foundation]] (local stack).

Created 2026-07-27 when the first server deployment and CI/CD pipeline were set up.

## At a glance

1. The monorepo (`photodome-api` + `photodome-ios`) lives at private GitHub repo `aidenhsy/photodome`; `photodome-design-system` is a separate repo and is gitignored.
2. Pushing to `main` with changes under `photodome-api/**` triggers `.github/workflows/deploy.yml` ("API CI and Deploy", since 2026-07-27): a `verify` job (lint, build, unit + e2e suites against composed test services, production image build) gates the `deploy` job; PRs run `verify` only. The runbook and workflow rules live in [[Deployment & Release]].
3. The workflow SSHes to the shared GCE server `34.84.34.186` (user `aidenhsy`, secret `SSH_PRIVATE_KEY`), hard-resets `/var/www/photodome` to `origin/main`, and runs `docker compose -f docker-compose.prod.yml up -d --build` in `photodome-api/`.
4. The compose stack is three containers: `photodome-api` (host port **4056**), `photodome-postgres` (postgres:17, internal only), `photodome-redis` (redis:7, internal only). The image runs `prisma migrate deploy` before booting the app.
5. The workflow polls `http://127.0.0.1:4056/v1/health` for up to 60 s and fails the run (with container logs) if the API never comes up.
6. The public entry point is `https://api.kindredarc.com` — an nginx vhost (`/etc/nginx/sites-enabled/photodome-api`) terminates TLS with a certbot-managed Let's Encrypt cert and proxies to `127.0.0.1:4056` with WebSocket upgrade headers for Socket.IO; HTTP redirects to HTTPS.

## How it works

- **Server layout:** `/var/www/photodome` is a clone of the monorepo. Untracked server-only files sit in `photodome-api/`: `.env` (chmod 600) and `gcp-credentials.json` (the `photodome-media` service-account key). The deploy uses `git reset --hard` (never `git clean`), so these survive every deploy.
- **Runtime env:** `NODE_ENV=production`, which activates the M7 fail-closed guards — real GCS only (`GCS_API_ENDPOINT` empty), `METRICS_BEARER_TOKEN` required, non-default `CAPABILITY_PEPPER`, `APNS_ENVIRONMENT=production` with full ActivityKit credentials. `CAPABILITY_PEPPER`, `METRICS_BEARER_TOKEN`, and the postgres password were generated with `openssl rand -hex` on the server and exist nowhere else — they are not in any repo, vault, or local machine.
- **Database:** the stack runs its own postgres:17 container with a named volume (`photodome-api_photodome-postgres`), unlike foodapp which uses an external postgres host. Migrations apply at container start via `start:prod` (`prisma migrate deploy && node dist/src/main.js`; `prisma` was moved to production `dependencies` so it survives `npm prune --omit=dev`, same as foodapp).
- **Media:** GCS project `younger7`, bucket `photodome-dev` — the validated bucket, confirmed 2026-07-27 as the one to keep using in production. If that ever changes, only `MEDIA_BUCKET_NAME` in the server `.env` changes.
- **APNs:** PhotoDome reuses foodapp's APNs auth key (`.p8` keys are Apple-team-scoped, and both apps are on the `com.younger7jp` team) with `APNS_BUNDLE_ID=com.younger7jp.photodome`.

## Decisions & gotchas

- **GitHub Actions billing can block deploys silently-ish.** Both first runs failed in ~3 s with "The job was not started because recent account payments have failed or your spending limit needs to be increased" — an account-level GitHub billing condition, not a workflow bug. foodapp deploys hit the same wall when it occurs. Fix in GitHub → Settings → Billing & plans. The deploy script can always be run manually over SSH (it is exactly the workflow's `script:` block).
- **Port 4056 is not reachable from the internet — only nginx is.** The GCP firewall only passes 80/443/22, so all public traffic goes through the `api.kindredarc.com` vhost (added 2026-07-27; same pattern as foodapp's `api.munchmunch.app` → `127.0.0.1:4046`). `client_max_body_size` is 10m because media uploads go direct to GCS via signed URLs — only small JSON bodies hit the API.
- **Deploys force-sync, never merge.** `git fetch && git reset --hard origin/main` keeps a drifted server working tree from wedging future deploys; untracked files (`.env`, credentials) are deliberately spared because there is no `git clean`.
- **The local `docker-compose.yml` is dev-only** (postgres + redis + fake-gcs for a host-run app); the server uses `docker-compose.prod.yml` exclusively, and every compose command in the pipeline passes `-f docker-compose.prod.yml`.
- **APNs environment vs dev builds:** the server runs `APNS_ENVIRONMENT=production` (forced by the production guard), so Live Activity pushes will only reach TestFlight/App Store builds; Xcode-run development builds use the sandbox APNs environment and won't receive them.
- **First health probes reset the connection** for ~15 s while migrations run and Nest boots; the 30×2 s retry loop absorbs this.

## Key files

- `.github/workflows/deploy.yml` — the pipeline (repo root, paths-filtered to `photodome-api/**`).
- `photodome-api/Dockerfile` — multi-stage node:22.12.0-alpine build; prunes dev deps; `CMD npm run start:prod`.
- `photodome-api/docker-compose.prod.yml` — api + postgres + redis stack.
- `photodome-api/.dockerignore` — keeps `.env`, `gcp-credentials.json`, `node_modules`, and fake-GCS data out of the image.

## Related

- [[M7 Release Checklist]] — production deployment was one of its external gates.
- [[GCS Development Bucket Validation]] — the bucket and service account this deployment uses.
- [[Release Versioning]] — how server releases relate to app versions.
- [[Reference Doc Rules]]

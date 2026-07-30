# PhotoDome handoff

Everything a new maintainer needs that is NOT in this repository. The repo itself is
self-contained: code in `photodome-api/` and `photodome-ios/`, full product
documentation in `docs/` (start with `docs/README.md`). No secrets are in the repo or
docs by policy — each item below must be handed over privately (password manager
share, in person, etc.). Check items off as they're transferred.

## Accounts and access

- [ ] **GitHub repo** `aidenhsy/photodome` — transfer ownership or add as admin
      collaborator. Pushing to `main` deploys the API to production, so this is also
      deploy access. Note: branch protection is unavailable on the current plan; the
      no-direct-push-to-main rule is enforced by convention (see `AGENTS.md`).
- [ ] **GitHub Actions secrets** — the deploy workflow uses `SSH_PRIVATE_KEY` (and any
      other repo secrets under Settings → Secrets). If the repo is transferred,
      confirm secrets carried over; if not, re-create them.
- [ ] **GCE server** `34.84.34.186` (user `aidenhsy`) — SSH key access. Hosts the
      Docker stack; the deployed clone lives at `/var/www/photodome`. See
      `docs/reference/Server Deployment.md`.
- [ ] **Server-only files** (never committed): `photodome-api/.env` and
      `photodome-api/gcp-credentials.json` on the server. Hand over copies or
      regenerate. New required env vars must exist in the server `.env` before a
      merge, or startup fails closed.
- [ ] **Google Cloud** — project `younger7`: GCS bucket `photodome-dev` (the
      confirmed production media bucket) and the service account behind
      `gcp-credentials.json`. Grant IAM access or create a new service account.
- [ ] **DNS / domain** — `api.kindredarc.com` points at the GCE server. Access to the
      DNS zone (and whatever terminates TLS) is needed for any server move.
- [ ] **Apple Developer / App Store Connect** — team `com.younger7jp`: app record,
      TestFlight builds (`0.1.0` line), signing, and the APNs `.p8` auth key
      (currently shared with foodapp; team-scoped). Add as team member or migrate the
      app to a new team.
- [ ] **Local iOS signing** — the new maintainer needs their own certificates and the
      team selected in Xcode; project config is generated from
      `photodome-ios/project.yml` via `xcodegen` (never edit the pbxproj directly).

## State at handoff (2026-07-31)

- MVP implemented through M6 plus the local M7 release-hardening tranche.
- Production API is live at `https://api.kindredarc.com`; deploys run automatically
  on push to `main` after a green `verify` job.
- `0.1.0 (3)` is uploaded to App Store Connect as the TestFlight candidate; the
  physical-device proof and remaining ASC metadata gates are tracked in
  `docs/releases/` and `docs/specs/M7 Release Checklist.md`.
- Known open TBDs (business model, launch audience, crash/alerting provider, etc.)
  are listed under "Still TBD" in `docs/README.md`.

## First hour for the new maintainer

1. Read `docs/README.md` top to bottom — it is the documentation map.
2. Read `AGENTS.md` and `CLAUDE.md` — working rules, branch/deploy workflow, and
   media-lifecycle constraints that must not be violated.
3. Get the API running locally per `docs/reference/M0 Development Foundation.md`
   (local dev API port is 3663).
4. Before any release work, read `docs/reference/Deployment & Release.md`.

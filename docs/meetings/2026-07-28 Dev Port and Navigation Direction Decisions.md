---
type: meeting
tag: decision
status: complete
updated: 2026-07-28
---
# 2026-07-28 Dev Port and Navigation Direction Decisions

Working-session decisions from a local development session on 2026-07-28, recorded so future work does not re-litigate them.

## Decision 1 — Local dev API runs on port 3663

The local `photodome-api` moved from the default port 3000 to **3663** ("DOME" on a phone keypad) so the project has a distinctive dev port, mirroring how foodapp reserves its own. Confirmed by the founder after a "can't connect to the server" report that turned out to be the local API simply not running.

- `photodome-api/.env` sets `PORT=3663` (gitignored; each machine sets its own).
- `photodome-ios/project.yml` Debug config points at `http://127.0.0.1:3663`; regenerating with `xcodegen generate` is required after pulling.
- Production is unaffected: the server's own `env_file` drives `docker-compose.prod.yml` (`:4056` behind nginx at `api.kindredarc.com`), and the iOS Release config still targets `https://api.kindredarc.com`.
- Shipped in PR #15 (`574f35d`); dev-port references updated in [[Deployment & Release]], [[M1 Accountless Event Spine]], and [[M2 Direct Upload and Live Album]].

## Decision 2 — Host-transfer sheet loses its share action

The Transfer host sheet's **Share transfer link** exported the placeholder `photodome.invalid` URL — the same defect PR #8 removed from the invite card, compounded here because the payload is a one-time host-authority credential the sheet itself says never to post publicly. The founder asked whether to comment it out; the confirmed direction is the established pattern instead: remove the affordance, keep the QR as the only transfer path, and guard with a UI regression. Details in [[2026-07-28 Host transfer – tap Share transfer link – unfinished placeholder link is offered]] (PR #15, `574f35d`).

## Decision 3 — Navigation direction stays industry standard

The founder asked for the home → Archives navigation to slide in from the leading edge (a "stepping into the past" metaphor). A custom leading-edge cover transition was built and evaluated in the simulator, then the founder confirmed the opposite decision: **all navigation follows the platform-standard push direction** — deeper content enters from the trailing edge, back reveals toward it — for consistency with the event-detail push, users' muscle memory, and the free interactive edge-swipe-back gesture. The custom transition was fully reverted before merge; Archives uses a plain `navigationDestination` push.

Treat this as the standing rule for future navigation work: do not customize push direction for metaphorical reasons without a new explicit founder decision.

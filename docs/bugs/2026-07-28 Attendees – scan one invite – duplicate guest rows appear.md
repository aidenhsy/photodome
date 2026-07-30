---
type: bug
status: fixed-pending-verification
updated: 2026-07-28
---
# Attendees – scan one invite – duplicate guest rows appear

**Date:** 2026-07-28  
**Severity:** High — one physical join can create phantom attendees, consume event capacity, and leave an orphaned capability that the guest's phone does not retain.  
**Surface:** iOS · Join → Scan QR code; API · `POST /v1/events/join`  
**Files:** `photodome-ios/PhotoDome/Features/Events/QRScannerView.swift` · `photodome-ios/PhotoDome/Features/Events/JoinEventView.swift` · `photodome-api/src/modules/events/`

## Environment

- Reporter: host using TestFlight `0.1.0 (2)`
- Guest: physical iPhone using TestFlight `0.1.0 (2)`
- Backend: production `https://api.kindredarc.com`
- Reproducible: confirmed from one physical QR join; deterministic through concurrent API regression

## Expected vs Actual

**Expected:** Scanning one valid invite creates exactly one guest membership. Repeated scanner callbacks or transport retries resolve to that same member and capability.

**Actual:** The attendee sheet showed the reported guest twice with the same display name and join minute. Production contained two active guest records.

## Reproduction Steps

Starting state: a host displays a valid invite QR and the guest is not yet an event member.

1. On the guest iPhone, open **Join** → **Scan QR code**.
2. Hold the same QR in the VisionKit scanner until the sheet dismisses.
3. On the host iPhone, open **N attending**.
4. Observe two attendee rows for the one guest.

## Diagnostic evidence

Production request logs contained two successful requests from the same IP, user agent, and installation signal:

```text
POST /v1/events/join → 200
POST /v1/events/join → 200, 0.609 seconds after the first request began
```

PostgreSQL recorded the two memberships 0.614 seconds apart.

The QR scanner called its payload closure for every VisionKit `didAdd` callback and relied on asynchronous sheet dismissal to stop scanning. `JoinEventView` did not claim an in-progress scanner submission before starting its unstructured task. The API generated a random capability and inserted a new `EventMember` for every valid request, with no retry binding.

## Root cause

This is a cross-layer idempotency failure:

1. VisionKit recognized the still-visible QR twice before dismissal completed.
2. Both callbacks started independent join tasks.
3. The API treated each valid code submission as a distinct person.
4. Both serializable transactions inserted a guest because display names are intentionally not unique and no installation-scoped join binding existed.
5. The host correctly rendered both real database rows.

The attendee list itself did not duplicate one response, and PostgreSQL did not duplicate one insert.

## Production remediation

Both active duplicate guest memberships were revoked on 2026-07-28 after verifying they had no contributed photos. The event returned to one active member (the host), allowing the guest to rejoin after deployment.

## Fix

- The VisionKit coordinator now claims only the first valid detection and immediately stops scanning.
- The join sheet claims its async scanner submission before starting the API task.
- The API derives purpose-separated retry material from the normalized invite code plus the already-present device-local installation signal.
- `event_members.join_binding_hash` is unique within an event. A retry returns the existing member and the same deterministic guest capability without publishing another `member_joined` event.
- Host removal clears the retry binding and replaces the revoked capability hash, so the same installation may intentionally join again while the invite remains valid.
- The installation signal still cannot authorize event routes by itself; the event capability remains required.

## Verification

- API format, strict lint, production compilation, production Docker image build, and 26 unit tests pass.
- The complete five-suite API E2E run passes. Its PostgreSQL-backed join regression sends two requests concurrently and proves one active guest row, the same member ID/capability, member count `2`, and successful remove/rejoin behavior.
- Swift format and strict lint pass; the signed generic iOS Release build succeeds.
- The complete iOS scheme passes 55 unit tests (50 passed, five expected opt-in live-API skips) and all 16 UI/accessibility tests. The focused QR regression proves the submission gate accepts only the first detection.
- [PR #17](https://github.com/aidenhsy/photodome/pull/17) squash-merged as `6f17904`; production workflow `30308694650` passed verification and deployment.
- Post-deploy checks confirm liveness/readiness `200`, all three PhotoDome containers running, migration `20260727214500_idempotent_guest_join` applied, the unique join-binding index present, and the remediated event at one active host with zero active guests.
- Physical QR verification remains required before this report moves to `fixed`.

## Pattern lesson

Camera and scanner delegates may emit the same semantic result more than once before navigation reacts. Claim the action synchronously at the delegate boundary, and make the server mutation idempotent using an opaque, purpose-separated retry binding. UI disabling alone is not a transactional guarantee.

## Related

- [[M1 Accountless Event Spine]]
- [[Architecture and Implementation Plan v0]]
- [[Release 0.1.0 (Build 3)]]
- [[Bug Report Rules]]

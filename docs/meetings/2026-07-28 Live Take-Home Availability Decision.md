---
type: meeting
tag: decision
status: complete
updated: 2026-07-28
---
# 2026-07-28 Live Take-Home Availability Decision

## Context

Requiring attendees to wait for the host to end an event before they can use
bulk take-home actions creates avoidable coordination friction. An attendee
should not have to remind or locate the host merely to save the photos already
available to them.

## Confirmed decision

- Hosts and guests can use private photo review and bulk saving during a live
  event as soon as at least one eligible ready photo exists.
- The live-event actions are **Choose photos** and **Save current photos**.
  “Current” makes clear that more contributions may arrive later.
- After the event ends, the same bulk action is labeled **Save all**.
- **Choose photos** and the lifecycle-specific bulk action stay together in one
  horizontal row. On narrower widths, each control first removes its decorative
  icon, then uses a slightly smaller full label if needed. Labels never wrap
  onto a second line.
- New ready photos join an attendee's remaining private review queue without
  resetting earlier Keep/Skip decisions.
- Repeating a bulk save omits photos already recorded as saved on that device,
  so an attendee can return later for newly available photos.
- The take-home actions remain hidden when there are no ready photos and while
  an event is expiring.

## Rationale

Take-home is a participant action, not a host lifecycle control. Making it
available during the live phase removes a dependency on the host while the
snapshot-specific label avoids implying that a still-growing album is final.

## Related

- [[Product Discovery Brief]]
- [[Architecture and Implementation Plan v0]]
- [[M5 Personal Curation and Download]]

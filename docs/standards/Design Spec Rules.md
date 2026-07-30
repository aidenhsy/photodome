# Design Spec Rules

Authoring standard for **forward-looking design specs / PRDs** — written *before* building to align on what to build and how. In Diátaxis terms this is the "decide" artifact that precedes the code. Distinct from post-build [[Reference Doc Rules]] (how the shipped thing works) and from [[Bug Report Rules]] (defects). Indexed in [[Doc Standards]]. Synthesised from the GitHub developer-docs guide, the "design documents that actually help" write-up, and ModernRequirements' 6Cs.

## When to write — and when not to

Write a spec when the change has **trade-offs, cross-team impact, or a non-obvious approach** — anything where writing it down forces a better decision or earns alignment.

**Skip it** when the solution is obvious and has a single reasonable implementation with no meaningful trade-offs. A spec written to rubber-stamp a decision already made is waste. (The "when NOT to write" test from the design-doc literature.)

## File naming

`<Feature Name>.md`, or `<Feature Name> PRD.md` for product-level specs. Title case, no date prefix — the spec is living until the feature ships.

## Required structure, in this order

### 1. `## Overview & Context`

- **The pitch** — 1–2 sentences: what the feature is and why it matters.
- **Strategic alignment** — how it ties to current business goals or user needs.
- **Current state** — the baseline problem / pain point users feel today.

### 2. `## Goals & Non-Goals`

- **Goals (in scope)** — 3–5 specific, *measurable* outcomes.
- **Non-Goals (out of scope)** — state explicitly what you're *not* doing. This is the cheapest scope-creep insurance you can buy.

### 3. `## Users & Scenarios`

Target audience + concrete user stories: *"As a [user], I want to [action] so that [benefit]."* Walk the main path step by step.

### 4. `## Acceptance Criteria`

The conditions that make the feature "done." Use **Given-When-Then** so the criteria are directly testable. Include **edge cases**: invalid input, a dependency failing, empty/maximal states.

### 5. `## Proposed Solution & UX`

- **High-level flow** — how the system handles the feature (not full implementation).
- **Visuals** — embed wireframes / flowcharts / mockups; they parse faster than prose.
- **Design links** — clickable links to the *editable* design files (Figma) so devs can reference them later.

### 6. `## Alternatives Considered`

A table of the options you weighed, with pros/cons and **why each was rejected**. This section is what proves you thought it through — don't skip it on anything non-trivial.

### 7. `## Technical & Cross-Cutting Concerns`

- **Dependencies** — other services, APIs, DB/schema changes required.
- **Constraints** — technical or timeline limits.
- **The boring stuff** — performance, security, monitoring/alerting, analytics. Briefly, but on the record.

### 8. `## Milestones & Open Questions`

Calendar dates + user-facing deliverables; and a list of unresolved decisions that still need input. It's fine — encouraged — to ship a spec with open questions flagged.

### 9. `## Related`

Wikilinks to related specs, the eventual reference doc, and this rules doc (`[[Design Spec Rules]]`).

## Quality bars

Inherits the shared 6Cs and bars from [[Doc Standards]]. Spec-specific emphasis:

- **Describe what, not how.** Outcomes and behaviour, not full schemas or step-by-step code.
- **Trade-offs over perfection.** Make decisions and their costs explicit; that's the value, not a flawless plan.
- **Real numbers.** Success metrics and constraints as measurable values, not "fast" / "scalable."
- **Prioritise** with MoSCoW (Must/Should/Could/Won't) where the scope is contested.
- **Share early drafts.** A spec is a collaboration tool; circulate before it's polished.

## Lifecycle

Living until the feature ships. On ship, either archive it or **distill the "how it actually works" into a reference doc** ([[Reference Doc Rules]]) and cross-link the two — the spec records the *intent*, the reference doc records the *reality*, and they drift apart over time.

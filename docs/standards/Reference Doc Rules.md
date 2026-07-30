# Reference Doc Rules

Authoring standard for **post-build reference docs** — notes that capture how a shipped feature or subsystem *actually works*, for future-you reloading context months later. In Diátaxis terms these are **Reference + Explanation** (the "what" plus the "why"). Distinct from forward-looking [[Design Spec Rules]] (written before building) and from [[Bug Report Rules]] (defects). Indexed in [[Doc Standards]]. Examples that already follow this shape: Email OTP Sign-in, Edit Review (both external).

## When to write one

- A feature shipped, **or** its architecture is non-obvious enough that you'd have to re-read the code to remember how it fits together.
- After a design spec's feature lands — distill "how it ended up working" here and link back to the spec.

**Don't** use this format for: deciding what to build (use [[Design Spec Rules]]), recording a defect (use [[Bug Report Rules]]), or pure step-by-step task instructions (that's a how-to/procedure — keep it separate, like the external "Food Journal Review Procedures" note).

## File naming

`<Feature Name>.md` — title case, **no date prefix**. These are living docs named by the feature/subsystem, not dated events (the opposite of bug reports). Name by the thing, not the change: `Edit Review.md`, not `Add edit button to feed.md`.

## Required structure

### 1. Intro paragraph (no heading)

1–3 sentences stating what the doc covers, with `[[wikilinks]]` to related docs. Name the type implicitly — open with "Reference doc for…" or an equivalent. A reader must be able to tell in one line whether this doc is what they need.

### 2. Provenance line

`Created YYYY-MM-DD when <the change that prompted it>.` When you add a section later, prefix it with `Added YYYY-MM-DD …` rather than silently rewriting history.

### 3. `## At a glance` (or "Flow at a glance")

The 30-second version: a short numbered flow or one paragraph of architecture. The reader who only reads this section should still come away with the shape of the thing.

### 4. Body sections — shaped to the feature

Use the subset that fits; don't force-fill. Recommended menu:

- **Entry points / Endpoints / Surfaces** — a table is ideal (where it's triggered → which file/function). Backend: method · path · operationId · what it does. UI: where · affordance · file.
- **How it works** — the mechanics (the "what").
- **Decisions & gotchas** — *why this way*, plus the traps (the Explanation half, and the single highest-value section). Name the non-obvious flag, the no-op default, the ordering constraint. This is what future-you actually comes back for.
- **Key files** — repo-relative paths to the files that hold the behaviour.
- **Config / env vars** — if any; note where they're read and any restart/boot caveat.
- **Edge cases / failure modes** — what happens when inputs are invalid or a service fails.

### 5. `## Related`

Wikilinks to PRD/design-spec sections, sibling reference docs, and this rules doc (`[[Reference Doc Rules]]`) for provenance.

## Quality bars

Inherits the shared 6Cs and bars from [[Doc Standards]]. Reference-specific emphasis:

- **What + why, not how-to-rebuild.** Describe the design and the reasons; don't paste full schemas or step-by-step build instructions.
- **No mystery actors.** Name the mechanism (`LazyVStack` recycler, the `onOpenComposer` no-op default), or label it unknown — never "somehow."
- **Self-contained.** Paste the key excerpt; don't make the reader open the repo to follow along.
- **Document the gotcha, always.** If you hit a non-obvious decision while building, it belongs in "Decisions & gotchas" — that's the part that pays for the doc.

## What to deliberately leave out

No Goals/Non-Goals, Personas, Acceptance Criteria, Milestones, or Mockups — those are prescriptive, forward-looking, and belong in the [[Design Spec Rules]] doc written *before* the build. A reference doc is **descriptive**: it reports reality, it doesn't propose it.

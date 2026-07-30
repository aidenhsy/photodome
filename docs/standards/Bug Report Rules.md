---
type: standard
status: living
updated: 2026-07-26
---
# Bug Report Rules

Authoring standard for every bug-report file under any `bugs/` folder in this vault. Distilled from QAWolf's *What Makes a Great Bug Report* and adapted for an Obsidian + personal-codebase context. If a section doesn't apply to a specific bug, write `n/a` — never omit the section.

## File naming

`YYYY-MM-DD <Title following [Area] – [Action] – [Result]>.md`

- Date first so the folder sorts chronologically.
- Title is a sentence fragment: where in the app, what the user does, what they see go wrong. Examples:
  - `Profile feed – scroll between own reviews – dish-name banner missing on all cards except the tapped one`
  - `Composer – pick photo without rating – Save Draft button stays disabled`
- Avoid vague titles like `Profile bug` or `Dish label issue`.

## Required sections, in this order

### 1. Header (no heading)

Four lines below the H1, each as bold-prefix → value:

- `**Date:** YYYY-MM-DD` — when found, not when fixed.
- `**Severity:** Critical | High | Medium | Low — one-line justification`
  - Critical: blocks core flow (auth, save, publish) or causes data loss / revenue impact.
  - High: a major feature is broken with no workaround.
  - Medium: a visible feature is broken but a workaround exists, or the wrong data shows without data loss.
  - Low: cosmetic, edge-case-only, or affects a tiny subset of users.
- `**Surface:** <platform> · <screen / flow path>` — e.g. `iOS · Profile tab → tap photo → ReviewFeedView`.
- `**File:** <repo-relative path to primary file involved>` — link to the code that holds the bug; multiple files allowed, one per line.

### 2. `## Environment`

Bulleted list. At minimum: device, OS version, build flavor (Debug / Release / which staging), backend URL or env, and a *reproducible: every time | sometimes (~X%) | once* note. For backend-only bugs, replace device/OS with Node version, DB version, deploy SHA.

### 3. `## Expected vs Actual`

Two short paragraphs, labelled **Expected:** and **Actual:**. Write Expected as if the spec already exists — what should the user see. Write Actual as what they see today. No "should be obvious" — make it obvious.

### 4. `## Reproduction Steps`

A short prose line establishing the **starting state** (signed-in user with X, DB seeded with Y, etc.), then a numbered list. Each step is one user action; mention button labels, field values, wait times. The list must end with a step that explicitly says "Observe: …" describing the broken outcome. A teammate or future-you must be able to follow the list cold.

### 5. `## Visual evidence`

A screenshot or screen-recording link is ideal. When images aren't being saved, write a textual description of each screen instead — header text, layout, what the broken element looks like (or its absence). Be specific enough that a reader who never saw the bug knows what they would have seen.

Heading can be `## Screenshots`, `## Screen recording`, or `## Visual evidence (textual)` — pick the one that matches what you actually have.

### 6. `## Diagnostic evidence`

Logs, console output, stack traces, network traces — the raw signal that points at the cause. Paste actual lines in fenced code blocks. If you added instrumentation to capture the logs, include the exact command (e.g. `xcrun simctl spawn booted log stream …`) so a future investigator can recreate the capture. Trim to the relevant lines; for long traces, keep the prefix + the critical line + the suffix and elide the middle with `…`.

### 7. `## Root cause`

Explain *why* the code produces the actual behaviour, not just *what* it does. Reference specific lines / functions / state variables. Include a short code excerpt of the offending code (old version) so the report stands alone without needing the reader to open the repo. Walk through the failure sequence numerically.

### 8. `## What I ruled out`

A bullet list of every hypothesis you considered and rejected, with the evidence that ruled it out. This is the single most valuable section for the future-you who re-encounters a similar symptom — it tells them which branches *not* to re-explore. Format each bullet as:

> - **Hypothesis N — short name:** description, what you tried, what you saw. **Rejected.**

If a hypothesis was confirmed, end with **Confirmed cause:** instead of **Rejected**.

### 9. `## Fix`

Short prose explaining the strategy, then the after-version of the relevant code as a fenced block. End with one line about how you verified (manual repro re-run, test added, etc.).

### 10. `## Pattern lesson`

One paragraph generalizing the bug into a rule for future code. "Don't do X when Y; instead Z, because …". This is what makes a bug report a *learning* asset rather than a forensics report. Skip only if the bug is genuinely one-off (a typo, a stale config) — most bugs have a pattern lesson.

### 11. `## Related`

Wikilinks to:
- Other relevant brain notes (PRD sections, architecture docs)
- Sibling bug reports with similar shape
- This rules doc (`[[Bug Report Rules]]`) for self-documenting provenance

## Quality bars

- **Complete but concise.** Every required section, but no padding. If a section is one line, keep it one line.
- **Self-contained.** A reader must not need to open the repo, the chat history, or a screenshot to understand the bug. Paste the relevant excerpts inline.
- **Honest about uncertainty.** If the root cause is still unconfirmed, label the section `## Root cause (suspected)` and say what would confirm it.
- **No mystery actors.** "It doesn't work" / "the user said" / "somehow" are red flags. Name the actor (LazyVStack recycler, GCM token expiry, etc.) or label the actor as unknown and put it in `What I ruled out` as a remaining hypothesis.
- **One bug per file.** If you find a second issue while investigating, write a second file and link it under `Related`.

## When to write the file

- **As soon as the cause is confirmed.** Not after the fix lands — the diagnostic detail decays fast.
- **Update on fix.** When the fix ships, add the `Fix` section (or update it if it was provisional). Don't retroactively rewrite history — if you ruled something out incorrectly, leave the old bullet and add a "*Update YYYY-MM-DD:* …" note.

## Fix completion and release bookkeeping

A code change alone does not complete a confirmed bug. Use this sequence:

1. Run the most relevant automated tests and build checks. If the bug is device-, production-, or timing-dependent, keep the report at `fixed-pending-verification` until that runtime check passes.
2. Update this bug file with the fix, exact verification evidence, and honest status. Move it to `fixed` only after every required confirmation passes.
3. Find the release note marked `status: current` and add the bug under its **Bug fixes** section. Add any remaining physical-device or production check to that build's verification checklist.
4. Commit only the bug's code and tests to the affected repository's `main` branch. Preserve unrelated worktree changes; do not include them for convenience.
5. In the handoff, name the tests/checks run, link the bug and current-build records, and provide the branch plus commit hash.

If the brain vault is not Git-backed, save its documentation directly and commit the code/test changes in the relevant application repository. If a safe scoped `main` commit is blocked by branch state, conflicts, or overlapping uncommitted work, report that blocker instead of silently broadening the commit.

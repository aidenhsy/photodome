Index of the documentation standards I apply across projects — how to *write the docs*, not the code. Reusable rules that live above any single project, sitting beside Coding Standards (external). Each standard governs one **Diátaxis** documentation type so a doc never tries to be two things at once.

## The Diátaxis map

Documentation splits into distinct types by *when* it's written and *what* it serves. Pick the type first, then the matching standard:

| Type | Written | Answers | Standard |
|---|---|---|---|
| **Design spec / PRD** | Before building | "What should we build, and how?" | [[Design Spec Rules]] |
| **Reference + Explanation** | After building | "How does the shipped thing work, and why this way?" | [[Reference Doc Rules]] |
| **Bug report** | When a defect is found | "What broke, why, and how was it fixed?" | [[Bug Report Rules]] |
| **How-to / Procedure** | Any time | "How do I accomplish task X?" | _(none yet — e.g. the external "Food Journal Review Procedures" note is one)_ |
| **Tutorial** | Any time | "Teach me by doing" | _(none yet)_ |

The rule of thumb: a forward-looking artifact (Goals, Acceptance Criteria, Alternatives, Mockups) is a **Design Spec**; a backward-looking one (how it actually works, key files, gotchas) is a **Reference Doc**. Don't blend them — distill the spec into a reference doc once the feature ships, and link the two.

## Shared quality bars (the 6Cs)

Every doc, whatever the type, aims for: **clear, concise, complete, consistent, correct, concrete.** Plus:

- **Self-contained** — a reader shouldn't need the repo, the chat history, or a screenshot to follow it. Paste the relevant excerpts inline.
- **Important-info-first** — front-load what lets a reader decide if this doc is relevant.
- **Formatting sparingly** — bold/lists for emphasis, not decoration (≈10% or less).
- **Honest about uncertainty** — label unconfirmed sections and say what would confirm them.
- **What, not how** (specs) / **what + why** (reference) — describe outcomes and decisions, not implementation minutiae like full schemas.

## Standards

- [[Design Spec Rules]] — forward-looking design specs / PRDs. Overview, Goals/Non-Goals, user scenarios, acceptance criteria, proposed solution + UX, alternatives considered, cross-cutting concerns.
- [[Reference Doc Rules]] — post-build feature/reference docs (how a shipped thing works + why). Intro, provenance, at-a-glance, entry points/key files, decisions & gotchas.
- [[Bug Report Rules]] — defect reports under any `bugs/` folder.

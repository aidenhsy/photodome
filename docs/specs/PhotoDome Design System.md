---
type: spec
status: approved
updated: 2026-07-25
---
# PhotoDome Design System

## Overview & Context

PhotoDome is the final product name. Its permanent visual identity is a
black-and-white system built around shared, candid event photography: quiet
interface chrome, high-contrast actions, rounded geometry, and full-color
photos as the emotional center of every screen.

This specification supersedes the temporary M0 visual foundation. The
interactive reference lives in
`photodome-design-system`; native
tokens and primitives live in `photodome-ios/PhotoDome/Design`.

## Goals & Non-Goals

### Goals

- Make joining, capturing, viewing, and saving feel immediate and trustworthy.
- Keep controls visually quiet so event photos carry the color and emotion.
- Give SwiftUI and web/reference work one named, testable token vocabulary.
- Represent lifecycle, progress, success, warning, and destructive states
  without relying on color alone.
- Meet Dynamic Type, dark mode, reduced motion, and 44-point touch guidance.

### Non-goals

- Redesign approved product behavior or event lifecycle.
- Add gradients, decorative glass, or a marketing color palette.
- Copy Notion, Stoic, or foodapp layouts or brand assets.
- Add alternate icon concepts or decorative brand treatments beyond the
  approved dome-frame identity.

## Users & Scenarios

- A host creates an event and needs the QR/code share action to read instantly.
- A guest joins in motion and needs one clear path to the live album.
- An attendee captures or imports photos while upload state remains legible.
- A member reviews a mixed album and saves all or keeps a private subset.
- A host ends the live session, optionally restricts uploads, and understands
  the seven-day deletion window.

## Acceptance Criteria

- Brand primitives are exactly `#000000` and `#FFFFFF`.
- Light and dark semantic surfaces maintain readable text and controls.
- Interactive controls have a minimum 44×44-point target.
- Focus, selected, disabled, progress, error, and destructive states remain
  distinguishable without color.
- Photos use full color by default; overlays do not obscure faces or primary
  content.
- Lifecycle language consistently uses Live, Ended, Uploads restricted, and
  Deletes in N days.
- The Swift source and downloadable JSON/CSS/Swift token files use the same
  names and values.
- The reference covers identity, color, type, layout, components, product
  styleframes, lifecycle, content, accessibility, and handoff.

## Proposed Solution & UX

### Principles

1. Photos carry the emotion; interface chrome stays monochrome.
2. One dominant action per decision surface.
3. State is explicit in words, icons, shape, and only then color.
4. Rounded geometry feels human, not playful: 12-point cards and controls,
   circles for capture and compact icon actions.
5. Destructive and expiry language is literal and calm.

### Identity

- Name: **PhotoDome**
- Product line: **Every photo. One shared moment.**
- The line is approved interface/launch copy, not a locked public tagline.
- Mark: a circular dome above an open baseline. The production iOS icon keeps
  this geometry constant across default, dark, and tinted appearances.

### Color tokens

| Token | Value | Use |
|---|---:|---|
| `brand.ink` | `#000000` | Light primary action, dark text |
| `brand.white` | `#FFFFFF` | Dark primary action, light text |
| `neutral.soft` | `#F5F5F3` | Secondary surface |
| `neutral.hairline` | `#D8D8D4` | Borders and dividers |
| `neutral.graphite` | `#666662` | Secondary text |
| `neutral.charcoal` | `#171717` | Dark elevated surface |
| `neutral.night` | `#0A0A0A` | Dark page |
| `state.success` | `#248A3D` | Confirmed success |
| `state.warning` | `#C65F00` | Attention required |
| `state.danger` | `#C81E1E` | Error/destructive action |
| `state.information` | `#1768CA` | Informational state |

Semantic tokens choose the appropriate primitive for light and dark appearance:
`backgroundPrimary`, `backgroundRaised`, `mediaPlaceholder`, `textPrimary`,
`textSecondary`, `borderSubtle`, `actionPrimaryBackground`, and
`actionPrimaryLabel`.

### Typography

- Product UI: SF Pro Rounded through `.system(..., design: .rounded)`.
- Codes, counters, and technical values: SF Mono.
- Native sizes use Dynamic Type roles: large title, title, headline, body,
  subheadline, caption, eyebrow, and monospaced numeric.
- Support Dynamic Type rather than pinning production text to visual samples.

### Geometry and motion

- Spacing follows an 8-point rhythm: 4, 8, 12, 16, 24, 32, 48, 64.
- Page inset is 20 points on iPhone; common card/control radius is 12.
- Minimum touch target is 44; primary controls are normally 52 points high.
- Motion durations are 150 ms feedback, 220 ms state, 340 ms transition, and
  420 ms direct manipulation.
- Reduced Motion replaces spatial movement with short opacity transitions.

### Components

Native foundations include primary, outline, and quiet buttons; lifecycle
pills; status messages; and empty states. Product compositions include event
cards, join-code blocks, upload rows, photo tiles, selection controls, bottom
action docks, and lifecycle banners. Every async action shows idle, progress,
success, and failure behavior.

### Photography

Use candid, inclusive event photography with real interaction, available light,
and a mix of wide context and close detail. Avoid staged stock gestures,
heavy filters, monochrome photos, overlaid text on faces, and visual treatments
that make private event media look public or promotional.

### Content

Use short verbs: Create event, Join event, Add photos, End event, Save all.
Say exactly what will happen for destructive or irreversible actions. Never
imply that swiping removes a shared photo; it changes only the member's private
keep/skip set.

## Alternatives Considered

| Direction | Benefit | Reason not selected |
|---|---|---|
| Keep the M0 styling temporary | No immediate migration | Leaves product and implementation decisions unresolved. |
| Add a signature accent color | Faster visual recognition | Competes with user photography and weakens the permanent monochrome decision. |
| Pure utilitarian system UI | Smallest design layer | Does not provide a recognizable PhotoDome identity or shared handoff vocabulary. |
| Copy foodapp/Carte directly | Familiar implementation | PhotoDome needs event, privacy, and media-lifecycle patterns of its own. |

## Technical & Cross-Cutting Concerns

- Swift tokens must use adaptive `UIColor` providers for semantic colors.
- Components expose semantic tone/state rather than raw color choices.
- Contrast checks apply to text, icons, controls, focus indicators, and image
  overlays in both appearances.
- Token changes require synchronized Swift, JSON, CSS, reference, and tests.
- Product screenshots and reference imagery must not contain private production
  media, personal data, credentials, or event capabilities.

## Milestones & Open Questions

1. Permanent name and monochrome direction confirmed — complete.
2. Token, component, content, and accessibility system specified — complete.
3. Native SwiftUI foundation and interactive reference implemented — complete.
4. Product screens migrate incrementally without changing behavior — pending.
5. Production App Store icon artwork and export validation — complete.

No product-name, brand-direction, or app-icon execution questions remain open.
Business model, hosting/deployment, launch languages, and observability
ownership remain outside this design-system decision.

## Related

- [[PhotoDome]]
- [[Product Discovery Brief]]
- [[Architecture and Implementation Plan v0]]
- [[M0 Development Foundation]]
- [[M7 Release Checklist]]
- [[PhotoDome Design System Reference]]
- [[Design Spec Rules]]

---
type: reference
status: shipped
updated: 2026-07-28
---
# PhotoDome Design System Reference

## Introduction

PhotoDome now has a permanent monochrome identity and a shared implementation
layer for the SwiftUI product and interactive web reference. This document
records the behavior that exists as of 2026-07-25; it does not claim that every
legacy product screen has already migrated.

## Provenance

- Product decision and system rules: [[PhotoDome Design System]]
- Interactive reference:
  `photodome-design-system`
- Private production reference:
  `https://photodome-design-system.aidenhsy.chatgpt.site`
- Native implementation:
  `photodome-ios/PhotoDome/Design`

## At a Glance

| Area | Shipped foundation |
|---|---|
| Identity | Final name PhotoDome; permanent black/white brand primitives |
| App icon | Opaque 1024×1024 default, dark, and tinted dome-frame renditions |
| Appearance | Adaptive light, dark, and high-contrast reference modes |
| Type | SF Rounded product text; SF Mono codes and counters |
| Layout | 8-point rhythm, 20-point iPhone inset, 12-point common radius |
| Accessibility | 44-point touch minimum, text labels for state, Dynamic Type-ready tokens |
| Components | Three button levels, lifecycle pill, status message, empty state |
| Handoff | Swift, JSON, and CSS token downloads |

## Identity and Color

The interface is deliberately monochrome so event photos remain the dominant
color field. Exact brand values are black `#000000` and white `#FFFFFF`.
Supporting neutrals are Soft `#F5F5F3`, Hairline `#D8D8D4`, Graphite
`#666662`, Charcoal `#171717`, and Night `#0A0A0A`.

Success `#248A3D`, warning `#C65F00`, danger `#C81E1E`, and information `#1768CA`
are semantic feedback colors, not brand accents. State always also has a word,
icon, or structural treatment. The live state is a monochrome dot plus “Live,”
not a red brand badge.

## Token Architecture

`PhotoDomeTokens.swift` groups `Brand`, `Neutral`, `State`, adaptive
`Semantic`, `Space`, `Radius`, `Size`, `TypeStyle`, and `Motion`. `AppTheme`
remains a compatibility facade for existing screens while they migrate.

Equivalent public files are generated in the reference site's `public/`
directory:

- `photodome.tokens.json`
- `photodome.tokens.css`
- `PhotoDomeTokens.swift`

## Native Components

- `MonochromeButtonStyle`: dominant filled action with pressed and disabled
  feedback.
- `OutlineButtonStyle`: secondary action on transparent/adaptive surfaces.
- `QuietButtonStyle`: tertiary inline or compact action.
- `PhotoDomeLifecyclePill`: Live, Ended, Uploads restricted, and expiry tones.
- `PhotoDomeStatusMessage`: info, success, warning, and failure messaging.
- `PhotoDomeEmptyState`: centered symbol, title, explanation, and optional
  action slot.

All button styles preserve a minimum 44-point hit target.

## App Icon

The approved dome-frame mark ships in the iOS asset catalog as three opaque
1024×1024 RGB PNGs: default pure black/white, dark Night/Soft, and a one-color
tinted source. Xcode generates the smaller Home Screen, Settings, Spotlight,
and notification sizes; the system generates unprovided clear appearances.

The vector masters live under `photodome-ios/Brand/`. The deterministic
`Scripts/render-app-icons.swift` renderer reproduces the PNGs, and
`Scripts/validate-app-icons.sh` verifies dimensions, alpha, and catalog
registration. A Release archive confirmed all three renditions in `Assets.car`.

## Product Patterns

- Home keeps Create and Join persistent, hides Archives when there is nothing
  to recover, and uses a direct Archives route instead of a one-item drawer.
  Event cards prioritize lifecycle, photo/attendee counts, host relationship,
  and a relative deletion countdown over verbose timestamps.
- The Live Activity uses a bold event/status hierarchy, a large circular
  camera cue, and one full-width labeled capture action. It does not show a
  progress bar unless the underlying state has a real target or duration.
- Live album prioritizes an evenly spaced three-column grid of square,
  center-cropped thumbnails. Camera and photo import are equally sized,
  prominent actions directly above it; redundant album labels, empty-state
  explanation, and counts are omitted. The host invite QR/code lives in a
  focused sheet that opens after creation and remains available from the
  toolbar, so it does not push the album below the fold.
- Event summaries use one lifecycle/attendance row and show take-home actions
  only after the event ends. The camera relies on familiar controls and the
  returning upload preview instead of a permanent instruction banner.
- Review gives the photo the canvas and separates Keep, Skip, Undo, and save
  completion.
- Expiry always names the remaining time. “Deletes in N days” is preferable to
  vague urgency.
- Host restriction blocks new reservations but never visually implies that an
  already-reserved upload was cancelled.

## Content and Accessibility

Labels use direct verbs and sentence case. Destructive sheets name the target
and consequence before confirmation. Join codes use monospaced text and remain
selectable/readable rather than being encoded only in a QR.

The implementation supports dark appearance, Dynamic Type-compatible styles,
VoiceOver labels supplied by product views, reduced-motion substitutions, and
non-color status cues. Image overlays need case-by-case contrast checks because
event media varies.

## Gotchas

- Do not add rounded corners or shadows to the source artwork; iOS applies the
  platform mask and material treatment.
- Full-color photography is intentional; converting albums to monochrome
  conflicts with the system.
- Do not use semantic feedback colors for general decoration.
- Do not fork token values inside individual views.
- Do not describe the product line “Every photo. One shared moment.” as a
  legally or publicly locked tagline.

## Key Files

- `photodome-ios/PhotoDome/Design/PhotoDomeTokens.swift`
- `photodome-ios/PhotoDome/Design/PhotoDomeComponents.swift`
- `photodome-ios/PhotoDome/Assets.xcassets/AppIcon.appiconset`
- `photodome-ios/Brand/AppIcon.svg`
- `photodome-ios/Scripts/render-app-icons.swift`
- `photodome-ios/PhotoDome/Design/AppTheme.swift`
- `photodome-design-system/app/page.tsx`
- `photodome-design-system/app/globals.css`
- `photodome-design-system/public/photodome.tokens.json`

## Related

- [[PhotoDome Design System]]
- [[Product Discovery Brief]]
- [[M0 Development Foundation]]
- [[M7 Local Release Hardening]]
- [[M7 Release Checklist]]
- [[Reference Doc Rules]]

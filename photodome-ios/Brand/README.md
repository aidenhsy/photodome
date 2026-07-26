# PhotoDome app icon source

These SVG files are the deterministic production masters for the PhotoDome
dome-frame mark.

- `AppIcon.svg`: default pure-black/pure-white appearance.
- `AppIcon-dark.svg`: dark appearance using Night and Soft neutral tokens.
- `AppIcon-tinted.svg`: one-color luminance source for system tinting.

The artwork is a full square. Do not add rounded corners or shadows; iOS applies
the current platform mask and material treatment. `Scripts/render-app-icons.swift`
reproduces each master as a true non-alpha 1024×1024 PNG in
`PhotoDome/Assets.xcassets/AppIcon.appiconset`.

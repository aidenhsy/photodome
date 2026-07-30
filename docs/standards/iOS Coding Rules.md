---
updated: 2026-07-27
---
Rules for any iOS app I build. Currently applied to Handii's `fl-client-ios` and `fl-seller-ios`, and Food Journal's iOS app — see the Food Journal PRD (external) § iOS architecture for project-specific decisions on top of these general rules. Pairs with NestJS Backend Rules (external) on the backend side.

## Stack

- **UI**: SwiftUI for everything
- **Pattern**: MVVM, one ViewModel per screen
- **Language**: Swift 5.9+
- **iOS minimum target**: 16+ (Handii), 17+ (Food Journal — see the Food Journal PRD (external) for rationale around NavigationStack, Observation framework, MapKit improvements)
- **API client**: Apple `swift-openapi-generator` (build-time codegen from OpenAPI spec) + URLSession transport
- **Real-time**: `Socket.IO-Client-Swift` when needed (WebSocket isn't covered by OpenAPI)
- **Image caching**: Kingfisher for all remote images (both Handii and Food Journal). Do NOT use `AsyncImage` — see Images convention below.
- **Local storage**: Keychain (auth tokens), UserDefaults (preferences)
- **Logging**: `os.Logger` (`import OSLog`)
- **Error monitoring**: Sentry iOS SDK

**Project-specific deviations:**
- **Maps**: Handii uses Google Maps SDK; Food Journal uses Apple MapKit wrapped in `UIViewRepresentable` (for pin clustering control)
- **Push**: Handii uses Firebase Cloud Messaging (FCM); Food Journal uses APNs directly via the backend's `push-notification-job` (no Firebase dependency)
- **Auth providers**: Handii has Apple/Google/LINE/WeChat; Food Journal has Apple/Google/Email OTP
- **Default language**: Handii is Japanese; Food Journal is English (with localization scaffolded for ja/zh-CN/zh-TW)
- **Payments**: Stripe Payment Sheet (Handii); Food Journal has no payments in v0 (booking integration deferred to v1)

## API client (swift-openapi-generator)

The API client is generated from the backend's OpenAPI spec via Apple's `swift-openapi-generator`. **Never write API request/response types by hand** — they come from the spec.

### Files in `Core/Network/`

- `openapi.yaml` — copied from the backend's Swagger export
- `openapi-generator-config.yaml` — generator configuration
- `GeneratedClient.swift` — generated, **do not edit**
- `GeneratedTypes.swift` — generated, **do not edit**
- `AuthMiddleware.swift` — injects the Bearer JWT from Keychain into every authed request; intercepts `401 TOKEN_EXPIRED` to refresh and retry once

### Update workflow

When the backend API changes:

1. Export `openapi.json` from the backend's Swagger endpoint:
   - Handii (`fl-api`): `http://localhost:4066/api-json`
   - Food Journal (`foodapp-api`): `http://localhost:4046/api-json` per the Food Journal PRD (external)
2. Convert JSON → YAML (any converter; `yq -P` works)
3. Replace `Core/Network/openapi.yaml`
4. Run:
   ```bash
   swift-openapi-generator generate Core/Network/openapi.yaml \
     --config Core/Network/openapi-generator-config.yaml \
     --output-directory Core/Network/
   ```
5. Rename the outputs to `GeneratedClient.swift` and `GeneratedTypes.swift`

### Manual networking exceptions

Only networking code written by hand:
- **WebSocket** (Socket.IO) — not covered by the OpenAPI spec
- **File uploads** where the OpenAPI generator's multipart handling is awkward (rare; usually works fine via the generator)

## Project Structure

Standard layout — feature-folder organization with a shared `Core/`:

```
my-ios-app/
├── App/                        ← App entry point, app-level config
├── Features/
│   ├── Auth/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Models/
│   ├── Onboarding/
│   ├── Home/                   ← MainTabView (tab container only, no Home screen)
│   ├── [feature]/              ← One folder per major tab/feature
│   └── ...
├── Core/
│   ├── Network/                ← OpenAPI-generated client + AuthMiddleware
│   ├── Auth/                   ← Token storage, auth state
│   └── Extensions/
├── Resources/
│   └── Localization/           ← Localizable.xcstrings (iOS 17+) or .strings files per language
└── Assets.xcassets/
```

Each `Features/<name>/` typically has `Views/`, `ViewModels/`, and `Models/` subfolders if non-trivial. Trivial features can be flat.

## Conventions

### Naming

- Views: `*View.swift` (e.g., `SellerProfileView.swift`, `MapView.swift`)
- ViewModels: `*ViewModel.swift` (e.g., `BrowseViewModel.swift`)
- One ViewModel per screen — no shared ViewModels across screens
- ViewModels: `@Observable` (iOS 17+) or `ObservableObject` (iOS 16)

### View / ViewModel rules

- Views are stateless or near-stateless — all logic and state in the ViewModel
- ViewModel handles all API calls, data transformations, state changes
- API client returns typed Swift structs from the generated types — **never** expose raw JSON dictionaries to views
- ViewModels expose only the data the view needs, in display-ready shape

### Icons

- Prefer SF Symbols (`Image(systemName:)`) when a suitable symbol exists
- Only use custom image assets when SF Symbols doesn't cover the need

### Images / photos

- **Always load remote photos through Kingfisher — never `AsyncImage`.** `AsyncImage` cancels in-flight loads when a cell scrolls off screen and reloads from scratch, causing flicker and blank cells in feeds/grids. Kingfisher keeps loads cancellation-safe and memory/disk-caches for free.
- Go through the app's **single image wrapper** (`CachedImage` in Food Journal), never `KFImage`/Kingfisher directly — so the engine underneath can be swapped in one place. Reach for the existing wrapper before writing any image-loading code; if a project has none yet, make one as the first step.

### Localization

- All user-facing strings go through localization — **never** hardcode visible text in views
- iOS 17+: use `String(localized:)` and `Localizable.xcstrings` (string catalog)
- iOS 16: use `NSLocalizedString(...)` and `Localizable.strings` per language
- Default language and supported set is project-specific (see Stack section above)
- Date format follows locale: Handii uses `YYYY年MM月DD日`, 24h time, ¥ JPY; Food Journal uses locale-default formatting
- Store and transport timestamps as absolute instants, then format them at the presentation boundary with the viewer device's `TimeZone.current` and `Locale.current`. Never expose `TimeZone.abbreviation(for:)` or a numeric `GMT±…` / `UTC±…` offset as explanatory copy. Prefer `localizedName(for: .generic, locale:)`; if it still returns a numeric offset, show a localized “local time” label. Inject timezone and locale into shared formatters so DST, location-zone, and fixed-offset fallbacks have deterministic tests.
- Clipboard writes must provide immediate localized visual confirmation and post an accessibility announcement; replace stale dismissal work when copy is tapped repeatedly. Do not expose a share action until its payload is usable by the recipient in every supported handoff—placeholder, localhost, development-only, and `.invalid` URLs are not share-ready.

### Auth

- Tokens stored in **Keychain** (never UserDefaults). Items use `kSecAttrAccessibleAfterFirstUnlock`.
- `401 TOKEN_EXPIRED` handling: `AuthMiddleware` intercepts, refreshes via `/auth/refresh`, retries the original request once
- `401 TOKEN_REVOKED` handling: clear tokens, route to splash
- Sign-out: clear Keychain + reset in-memory state + call `POST /v1/auth/sign-out`

### Payments (when applicable)

- Stripe Payment Sheet for saving cards — **never** collect card numbers directly
- Apple Pay through Stripe's native integration

### Logging

- `os.Logger` for structured logs
- Sentry SDK for error monitoring (project-specific DSN)
- PII redacted from logs by default — don't ship emails or display names in error breadcrumbs unless explicitly tagged

### SwiftUI gotchas

- **`@Observable` environment objects don't cross modal boundaries.** Objects injected with `.environment(obj)` do NOT reliably propagate into a `.sheet` / `.fullScreenCover`'s content. If the presented view reads one via `@Environment(SomeService.self)`, you must **re-inject it on the presented content**:
  ```swift
  .sheet(item: $place) { place in
      NavigationStack { DetailView(place: place) }
          .environment(auth)   // ← without this, DetailView can't find AuthService
  }
  ```
  Symptom is nasty: the sheet **silently fails to present** (no crash, "nothing happens" on tap). Prefer passing dependencies as init params (e.g. `Repo(api: auth.api)`) where possible — that sidesteps the propagation issue entirely, which is why most sheets here don't hit it. Real case: Food Journal's editorial-guide sheet → `RestaurantDetailView` reads `AuthService` from the environment and wouldn't open until `.environment(auth)` was added (see the external "Explore Editorial Guides" note).

- **Clipping an aspect-fill image does not constrain its tap region.** In a
  `LazyVGrid`, `scaledToFill` media can retain an interaction region beyond the
  visible square even after `.clipped()` or `.clipShape(...)`. Neighboring
  buttons then overlap invisibly, and a tap near one row's edge can trigger the
  photo above or below it. Define the interaction shape on the button label
  after layout, and use one shared grid-cell component so it cannot be omitted:
  ```swift
  Button(action: onTap) {
      thumbnail
          .aspectRatio(1, contentMode: .fit)
          .clipped()
          .contentShape(Rectangle())
  }
  .buttonStyle(.plain)
  ```
  Add a UI regression that taps just inside both sides of a shared cell edge;
  center-only `.tap()` coverage will miss this class of bug. This recurred from
  foodapp's photo picker in PhotoDome's album-download grid; see
  [[2026-07-27 Event album – tap photo near grid-row edge – neighboring photo starts downloading]].

- **Treat signed media URLs as expiring credentials, never stable image
  identity.** A lazy grid can remain alive longer than a five-minute URL:
  thumbnails loaded early stay cached while rows first shown later fail, making
  intact media look deleted. Keep a stable media ID and the server-provided
  expiry alongside each URL. Refresh the page on foreground shortly before
  expiry, and let a current-URL load failure request one fresh page. Before
  recovering, compare the failed URL with current model state; once a refresh
  replaces it, ignore its callback. Coalesce in-flight refreshes and add a
  cooldown so dozens of cells or an offline transition cannot create a request
  storm. Test earliest-expiry selection, foreground replacement, and
  current-versus-stale failure behavior. See [[2026-07-27 Event album – scroll
  or return after signed URL expiry – photos show gray placeholders]].

- **Make user-created media optimistic by identity, not by progress text.**
  When a picker, camera, or composer returns local media, insert its preview in
  the destination UI immediately and overlay a loader on that media. A separate
  progress row leaves the user's actual content absent and makes a successful
  background operation feel stalled. Assign one client UUID before preparation
  or reservation and carry it into the durable transfer queue, then reconcile
  by the canonical server media ID when realtime or refresh publishes the
  result. Both handoffs must deduplicate because state publication and queue
  cleanup can race. Keep the protected local file for restoration and retry,
  show failed state on the media, and remove it only after canonical
  acknowledgement. Test temp-to-queue and queue-to-server replacement
  independently. This pattern applies to chats, album uploads, post composers,
  attachments, and document scans; see [[2026-07-27 Event album – select photo
  – upload appears only as a separate progress row]].

- **Attach source-relative presentations to the control that opened them.**
  SwiftUI uses the view carrying `confirmationDialog`, `popover`, or a similar
  modifier as the adaptive presentation source. A descendant button changing a
  root view's Boolean does not transfer that button's geometry to the root-owned
  presentation, so warnings can remain anchored near the top after the user
  scrolls and taps a lower item. Put the modifier on the exact button, cell, or
  row. For repeated content, use a stable-ID-scoped binding so only the selected
  item presents:
  ```swift
  Binding(
      get: { selectedItem?.id == item.id },
      set: { presented in
          if !presented, selectedItem?.id == item.id {
              selectedItem = nil
          }
      }
  )
  ```
  System placement is adaptive and may appear above or below the source to fit;
  do not hard-code popup coordinates. Keep screen-wide error alerts attached to
  the screen boundary because they intentionally have no single source. Add a
  UI regression that scrolls to a lower repeated row and opens its warning; see
  [[2026-07-28 Action confirmation – tap lower source – warning stays anchored
  near top]].

- **Treat a custom AVFoundation camera as a camera product, not just a preview
  plus shutter.** `AVCaptureSession` does not inherit the native Camera app's
  controls. A production photo surface needs an explicit baseline: discover and
  safely swap available front/back inputs; show supported Off/Auto/On flash;
  convert preview taps into focus and exposure points; clamp pinch and
  accessibility zoom to the active device range; handle preview/output rotation
  and front mirroring; and serialize configuration so lens/zoom/focus changes
  cannot race a capture. Product-specific one-tap saving may deliberately omit
  review/editing, but it should not accidentally omit pre-shutter photographic
  controls. Put controller decisions behind pure policies, test the shared
  control overlay without hardware, and keep a physical-device gate for input
  switching, flash, focus, mirroring, lens transitions, and image quality. See
  [[2026-07-28 Event camera – open capture – native camera controls are
  missing]].

## Build & run

```bash
open <project>.xcodeproj    # Open in Xcode
# Cmd+R to build and run on simulator
```

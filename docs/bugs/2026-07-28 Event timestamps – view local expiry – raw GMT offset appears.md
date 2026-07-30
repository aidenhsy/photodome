---
type: bug
status: fixed-pending-verification
updated: 2026-07-28
---
# Event timestamps – view local expiry – raw GMT offset appears

**Date:** 2026-07-28  
**Severity:** Low — the expiry instant is correct, but a technical GMT offset makes a user-facing deadline harder to understand.  
**Surface:** iOS · Event detail → ended summary → Photos expire  
**File:** `photodome-ios/PhotoDome/Domain/EventModels.swift`

## Environment

- User-reported device: iPhone model `TBD`
- User-reported OS: iOS version `TBD`
- User-reported build: PhotoDome build `TBD`
- Backend: production; exact URL `TBD`
- Reproducible: every time when Foundation returns a numeric abbreviation such as `GMT-4` for the device's current timezone

## Expected vs Actual

**Expected:** The expiry date and time use the iPhone's current timezone and identify it in plain language, such as `Eastern Time`, so the deadline is immediately understandable wherever the person is.

**Actual:** The expiry date and clock time are converted correctly, but the suffix can appear as the technical abbreviation `GMT-4`.

## Reproduction Steps

Starting state: an ended event has an `expiresAt` value and the iPhone is using a timezone for which `TimeZone.abbreviation(for:)` returns a numeric GMT offset.

1. Open the ended event.
2. Scroll to the event summary.
3. Read the **Photos expire** timestamp.
4. Observe: the timestamp ends in a technical offset such as `GMT-4` instead of a readable local timezone name.

## Visual evidence (textual)

The ended-event summary displays the correct expiry date and local clock time, followed by `GMT-4`. The numeric offset requires the person to translate it mentally and does not identify a familiar place-based timezone such as Eastern Time.

## Diagnostic evidence

The shared formatter appended Foundation's raw abbreviation after already formatting the date in the requested timezone:

```swift
style.timeZone = timeZone
let timestamp = date.formatted(style)
guard let abbreviation = timeZone.abbreviation(for: date) else {
    return timestamp
}
return "\(timestamp) \(abbreviation)"
```

Deterministic regressions now cover an IANA location timezone and a fixed-offset timezone:

```text
testFormatsEventTimeInTheRequestedLocalTimeZone passed
testUsesFriendlyLocalizedNameForUserTimeZone passed
testHidesNumericGMTOffsetBehindLocalTimeLabel passed
Executed 3 tests, with 0 failures
** TEST SUCCEEDED **
```

## Root cause

`EventTimestampFormatter.localDateTime` correctly assigned the supplied timezone to `Date.FormatStyle`, and every production call used its default `TimeZone.current`. The conversion was therefore already device-local. The formatter then used `TimeZone.abbreviation(for:)` as user-facing copy, but Foundation is allowed to return a numeric offset such as `GMT-4` rather than a familiar abbreviation or localized name.

Failure sequence:

1. The API supplies one absolute ISO 8601 expiry instant.
2. `Date.FormatStyle` converts that instant into the iPhone's current timezone.
3. `TimeZone.abbreviation(for:)` returns the platform's raw zone abbreviation.
4. Some timezone/locale combinations produce `GMT-4`.
5. The formatter exposes that implementation-oriented string directly in the UI.

## What I ruled out

- **Hypothesis 1 — the server stored the wrong expiry instant:** the ISO 8601 value parses successfully, and the displayed date and clock time match conversion into the requested timezone. **Rejected.**
- **Hypothesis 2 — the app always formats in UTC:** `Date.FormatStyle.timeZone` is explicitly assigned the passed timezone, whose production default is `TimeZone.current`; the Tokyo and Miami regressions prove the clock changes correctly. **Rejected.**
- **Hypothesis 3 — the seven-day retention rule is wrong:** this formatter changes presentation only; it does not calculate or mutate `expiresAt`, backend cleanup, or retention behavior. **Rejected.**
- **Hypothesis 4 — exposing `TimeZone.abbreviation(for:)` as display copy:** a fixed `GMT-4` timezone deterministically reproduces the raw suffix, while using the localized generic name produces `Eastern Time` for Miami. **Confirmed cause.**

## Fix

The shared event timestamp formatter continues to convert with `TimeZone.current`, but now asks Foundation for the locale-aware generic timezone name. If Foundation can only identify the zone with a numeric GMT/UTC offset, the formatter shows the localized `local time` label instead of exposing that offset:

```swift
let timestamp = date.formatted(style.locale(locale))
let timeZoneName = localTimeZoneName(timeZone, locale: locale)
return "\(timestamp) (\(timeZoneName))"
```

This one formatter supplies event start, end, expiry, and attendee-join timestamps, so the behavior is consistent across those surfaces. Swift formatting and lint pass. On the iPhone 17 Pro / iOS 26.5 simulator, all three focused formatter tests pass; the complete scheme passes 51 tests with 46 passed, 5 opt-in API integration tests skipped, and zero failures; and the Release simulator build succeeds. PR #7 was squash-merged to `main` as `5859094` on 2026-07-28. A physical-device check in the affected locale remains before this report moves to `fixed`.

## Pattern lesson

Store and transport timestamps as absolute instants, then format them at presentation time with the viewer device's current timezone and locale. Do not expose `TimeZone.abbreviation(for:)` or a raw GMT/UTC offset as explanatory UI copy; prefer a localized generic timezone name and fall back to a translated `local time` label when the platform only supplies a numeric offset. Inject timezone and locale into the formatter so conversions and fallback behavior are deterministic in tests.

## Related

- [[M1 Accountless Event Spine]]
- [[M4 Host Lifecycle and Moderation]]
- [[Product Discovery Brief]]
- [[iOS Coding Rules]]
- [[Bug Report Rules]]

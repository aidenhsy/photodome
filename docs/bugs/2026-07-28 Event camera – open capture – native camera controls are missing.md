---
type: bug
status: fixed-pending-verification
updated: 2026-07-28
---
# Event camera – open capture – native camera controls are missing

**Date:** 2026-07-28  
**Severity:** Medium — capture works, but users cannot choose the front camera or control common photographic behavior before PhotoDome immediately saves and shares the result.  
**Surface:** iOS · Event album or Live Activity → Camera  
**File:** `photodome-ios/PhotoDome/Features/Capture/EventCameraView.swift`  
**Resolution:** PR #11 established the baseline controls; PR #19 replaced its
1×/2× shortcut with device-aware lens presets. Both were squash-merged to
`main` on 2026-07-28.

## Environment

- User-reported device: iPhone model `TBD`
- User-reported OS: iOS version `TBD`
- User-reported build: PhotoDome build `TBD`
- Backend: not involved
- Reproducible: every app-owned camera session before the fix

## Expected vs Actual

**Expected:** PhotoDome's event camera retains its fast one-shutter save/share
flow while exposing the capture essentials users already understand from the
native Camera app: front/back switching, visible flash choice, tap focus, and
zoom.

**Actual:** The original preview always used the rear wide-angle camera. The UI
contained only Close and Shutter. Flash was silently forced to Auto when
supported, with no visible state or choice. There was no input swap,
tap-to-focus/exposure, or pinch/discrete zoom. PR #11 added those controls but
left discrete zoom as one button hard-coded to alternate between 1× and 2×,
hiding the available 0.5× and telephoto lens choices on multi-camera iPhones.

## Reproduction Steps

1. Open a live or upload-open event.
2. Tap **Camera**.
3. Look for a front/back switch control.
4. Look for the current flash state and try to change it.
5. Tap a subject to focus or pinch the preview to zoom.
6. Observe: none of those controls or interactions exists.

## Diagnostic evidence

The original controller configured exactly one input:

```swift
AVCaptureDevice.default(
    .builtInWideAngleCamera,
    for: .video,
    position: .back
)
```

Capture then created new settings and selected `.auto` without consulting user
state:

```swift
let settings = AVCapturePhotoSettings()
if output.supportedFlashModes.contains(.auto) {
    settings.flashMode = .auto
}
```

`EventCameraPreviewView` only hosted an `AVCaptureVideoPreviewLayer`; it had no
tap or pinch recognizers. This was a complete description of the missing
behavior—there was no hidden system control being suppressed.

## Root cause

PhotoDome uses a custom AVFoundation camera so one shutter can embed the
shutter-time location, save the prepared master, admit the event upload, and
return directly to the album. AVFoundation supplies capture primitives, not the
native Camera app's interface. Every lens, flash, focus, zoom, orientation, and
capture-state behavior must be implemented by the app.

M3 intentionally shipped a minimal rear-camera/automatic-flash proof of the
fast capture pipeline. The implementation treated that milestone shortcut as
the finished capture surface and did not establish a baseline-control checklist
for custom cameras.

## What I ruled out

- **Hypothesis 1 — iOS intentionally hides controls in third-party cameras:** AVFoundation exposes camera discovery/input replacement, flash modes, focus and exposure points, and zoom factors. **Rejected.**
- **Hypothesis 2 — the native Camera UI can be embedded while retaining PhotoDome's pipeline:** iOS does not expose the Camera app as a customizable embedded capture surface. A system picker would also break the direct one-shutter event workflow. **Rejected.**
- **Hypothesis 3 — flash is entirely absent:** the controller already requested Auto flash when supported; only the state and user choice were absent. **Rejected.**
- **Hypothesis 4 — the custom surface implemented only the milestone-minimum controller and shutter:** confirmed by the fixed rear input, hard-coded Auto flash, and gesture-free preview. **Confirmed cause.**

## Fix

The camera now:

- selects the best available rear virtual camera, falling back through
  triple/dual-wide/dual/wide hardware;
- swaps between the rear camera and front TrueDepth/wide camera without tearing
  down the capture session;
- exposes **Flash Off / Auto / On**, while showing Flash unavailable for a
  front camera without hardware flash;
- preserves the selected rear flash preference while the front camera is
  active;
- mirrors the front preview and front capture;
- focuses and meters exposure at the tapped preview point, with a visible focus
  indicator;
- supports continuous pinch zoom within the active device's real zoom range,
  capped at 10×;
- derives visible, accessibility-friendly zoom presets from the active
  camera's minimum zoom and virtual-device lens switch-over factors;
- includes the supported 2× crop alongside physical presets, producing rows
  such as 0.5×/1×/2×/5× on a representative triple camera while adapting to
  simpler rear and front hardware;
- ramps smoothly when a preset is selected while retaining bounded continuous
  pinch zoom; and
- disables switch/flash/zoom/shutter operations when they could conflict with
  an in-progress capture.

All AVFoundation configuration remains serialized on the camera session queue.
The existing PhotoDome-specific behavior is unchanged: a successful shutter
immediately embeds date/location, saves, queues the upload, and returns without
a Retake/Use Photo screen.

Automated coverage includes pure flash-resolution, zoom-clamping, and
device-preset derivation tests plus a production-overlay UI regression for
flash mode, 0.5×/1×/2×/5× preset presentation and selection, front/back
adaptation, front-camera flash unavailability, and shutter availability.

Verification completed on an iPhone 17 / iOS 26.5 simulator:

- strict Swift format/lint and app-icon validation pass;
- all 46 signed unit tests run with zero failures and five expected opt-in
  live-API skips, including the flash and zoom policy regressions;
- the focused production-overlay UI flow passes with one test and zero failures,
  covering flash cycling, discrete zoom, front/back switching, front-flash
  unavailability, and shutter availability; and
- the unsigned Release simulator build succeeds.

Physical-device verification is still required for actual input switching,
hardware flash firing, front-camera mirroring, autofocus/metering, optical lens
transitions, and capture quality before this report can become `fixed`.

The Build 3 lens-preset follow-up was verified on an iPhone 17 / iOS 26.5
simulator:

- strict Swift format/lint, app-icon validation, and Release configuration
  validation pass;
- the complete unit scheme reports 59 tests with zero failures and five
  expected live-API skips;
- all 17 UI tests pass, including the adaptive zoom-preset overlay regression;
- the signed generic-device Release build succeeds; and
- the app and Live Activity extension both report `0.1.0 (3)`.

The simulator cannot prove which presets a physical iPhone reports or that a
preset crosses to the expected optical constituent. Those checks remain the
reason this report is `fixed-pending-verification`.

## Pattern lesson

A custom `AVCaptureSession` is not the Camera app. Before calling a custom
camera complete, explicitly cover:

1. available front/back inputs and safe session-queue replacement;
2. visible supported flash state;
3. focus and exposure point conversion through the preview layer;
4. bounded zoom with both gesture and accessibility operation;
5. preview/output rotation and front-camera mirroring;
6. capture-in-progress exclusion;
7. permission, interruption, unavailable-device, and failure recovery; and
8. physical-device tests—simulators cannot prove camera hardware behavior.

The product may intentionally omit editing or confirmation screens, but that
decision must not silently remove basic pre-shutter capture controls.

## Related

- GitHub PR #11 — Add native event camera controls
- GitHub PR #19 — Expose device-aware camera lens presets
- [[M3 Camera and Live Activity]]
- [[Product Discovery Brief]]
- [[Media Upload and Retention]]
- [[iOS Coding Rules]]
- [[Bug Report Rules]]

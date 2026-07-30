---
type: meeting
tag: discovery
status: complete
updated: 2026-07-26
---
# 2026-07-26 Media Fidelity Decision

## Founder direction

PhotoDome is a photo-sharing product, so preserving the information carried by
the contributed photo is part of the sharing value. The downloadable master
must retain embedded GPS and other source metadata instead of stripping them.
The founder also approved the proposed quality/performance split:

- retain a full-resolution master for download;
- use separate optimized display and thumbnail variants for fast browsing;
- keep uploads direct, resumable, durable, and non-blocking;
- load thumbnails in grids, display variants for ordinary full-screen viewing,
  and the master only for download or a future deep-zoom need;
- avoid repeated lossy encoding of the master; preserve the encoded source
  where supported, or use at most one high-quality full-resolution encode when
  normalization is required.

## Confirmed product behavior

- For supported contributed still photos, the downloadable master preserves the
  source's embedded metadata, including GPS when present.
- PhotoDome's in-app camera requires authorized foreground precise location and
  embeds the capture coordinate in the contributed master. Denied, restricted,
  or reduced-accuracy authorization does not satisfy the camera requirement and
  must provide a route to iOS Settings.
- An imported photo keeps the GPS metadata already carried by that source.
  PhotoDome must not stamp an older imported photo with the device's location at
  import time.
- The full-resolution master is not used to render the live grid or normal
  full-screen album view.
- Display and thumbnail variants may remain metadata-free because the preserved
  master is the shared take-home asset.
- Precise location, capture time, and device/application metadata may therefore
  be available to every authorized event member who downloads the photo.
- Event access remains private to valid event capabilities, and every master,
  variant, and associated server record is still permanently deleted seven days
  after the event ends.

## Implementation result

Implemented and locally verified on 2026-07-26. The centralized create/join
preflight now requires Camera, Photos add-only, and foreground precise-location
authorization. Denied, restricted, and reduced-accuracy location states block
PhotoDome camera capture and route the person to iOS Settings; PhotoDome does
not request background or Always location.

At shutter time, the app requires a fresh precise coordinate, embeds it with
the capture date in the prepared master, saves that same prepared file to
Photos, and queues it for direct upload. JPEG library imports that need no
override remain byte-for-byte unchanged with their embedded metadata. Imports
without GPS receive no device/import-time coordinate. Other supported stills
are normalized with at most one full-resolution quality-0.95 JPEG encode.

The backend verifies the upload and generates metadata-free 2048 px display
and 512 px thumbnail variants without rewriting the stored master. Automated
iOS tests prove byte preservation, GPS/date embedding, and the no-import-time
GPS rule; the GCS-backed media E2E test proves the uploaded master remains
byte-for-byte identical after processing.

## Required follow-up

- Verify the complete import → upload → download → Photos metadata round trip
  and location allow/deny/restricted/reduced-accuracy recovery on physical
  iPhones.
- Re-evaluate App Store Connect privacy answers for precise location and other
  photo metadata against the final binary and deployed behavior.
- Keep image metadata out of application logs, traces, and analytics even
  though it is intentionally retained inside the private photo master.

## Open questions

- Whether location or other metadata should be visible/searchable inside the
  PhotoDome interface is `TBD`; preservation in the downloadable master is
  confirmed.
- Supported master formats beyond the current JPEG-only, 20 MB still-image
  boundary are `TBD`. ProRAW, Live Photos, and video remain out of scope unless
  separately approved.
- Exact contributor disclosure/acknowledgement UX is `TBD`, but the disclosure
  itself is required before release.

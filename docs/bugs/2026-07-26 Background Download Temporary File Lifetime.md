---
type: bug
status: resolved
updated: 2026-07-26
---
# Background download temporary file lifetime caused all saves to fail

## Symptom

After **Save all** downloaded the event originals, every item moved to **Needs attention** with “The downloaded photo could not be prepared.” No photos reached Apple Photos.

## Root cause

`URLSessionDownloadDelegate` supplies a temporary file URL that is valid only for the duration of `urlSession(_:downloadTask:didFinishDownloadingTo:)`. PhotoDome returned from that delegate method and then attempted to move the file inside an asynchronous main-actor task. By then iOS had deleted the temporary file.

The failure happened before `PhotoLibraryWriter` requested or checked add-only Photos authorization, so it was not caused by a denied Photo Library permission.

## Resolution

The delegate now synchronously moves the completed download into protected PhotoDome application storage before returning, then hands that stable URL to the asynchronous queue and Photos writer. Retry refreshes the signed manifest URL when no retained local file exists.

A unit regression test moves a representative delegate temporary file into the staging directory and verifies that its bytes remain readable after the source URL is gone.

## Related

- [[M5 Personal Curation and Download]]
- [[M7 Local Release Hardening]]

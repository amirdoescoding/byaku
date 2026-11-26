# Restart

**2026-11-27**: PR B1 `feat/face-scan` is pushed with a PR open, waiting for CI and the user's merge. Guided face scan
with a live mesh mask (camera beat → mask → sweep → straight/left/right → collapse into the ring). The user tested it on
their Mac after the deadlock fix: "everything is good".
- Deadlock: an AVCaptureVideoPreviewLayer on the session locked up with our Vision requests, so the camera beat now
  draws our own frames, and `Camera.stop()` runs off the main thread.

Next: B2, the multi-pose template behind a pre-registered margin bar. Still open: owner match after a rescan with a
second person or a photo.

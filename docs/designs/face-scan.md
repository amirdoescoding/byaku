# Guided face scan (as shipped, PR B1)

Replaces the 5 s countdown ring. The scan is used both in onboarding (step 2, 480 × 360 window) and in the menu's
Set up face… panel (360 × 352, `compact`). Both run the same `ScanView`.
- Prototype: `design/scan/prototype.html`. Serve it with `(cd design/scan && python3 -m http.server 8765)`. It has a
  scripted head and a live-camera mode (MediaPipe in the browser, design only, never shipped).
- Review sheets: `design/scan/sheet-{dark,light}.png`.
- Code: `Sources/Byaku/ScanView.swift`, plus `ScanPose` in `Owner.swift` and the `Tokens.Scan` values, which were
  ported 1:1 from the prototype.

## What the user sees

1. **Camera:** the mirrored camera, in monochrome at 85%, with a soft radial edge (a fade, not an oval). It holds for 1 s
   once a face is found.
2. **Mask:** a low-poly face mask fades on over the face (0.5 s), lined up with the camera image.
3. **Sweep:** an accent line sweeps down the face (0.9 s) and wipes the camera away above it. From here on, only the
   mask is left, and the camera image never returns, not on a pause and not on a retry.
4. **Poses:** straight, then left, then right. Each pose is captured after **1 s held inside its band**:
   - straight: |yaw| < 8°
   - sides: past 12°, with no upper limit, so a full turn counts.

   Leaving the band pauses the hold without resetting it. While a pose is held, its third of the mask fills from the
   inside out, then turns violet when captured (flick sound, the mascot raises its brows). After 4 s out of the side
   band, the words change to "A little further".
5. **Done:** the lit mask holds for 0.3 s, then springs into the mascot's ring. "Face saved" arrives with a brow raise
   and a two-note chime.

The mascot (56 pt, above the mask) cues each step:
- focus for straight
- looks screen-left for "left" (the display is mirrored)
- looks screen-right for "right"
- frowns on a pause

**Interrupts:** no face, or 2+ faces, pauses the scan. The mask dims to 30%, the mascot frowns, and the words say why
("Lost you", or "More than one face"). Progress is kept, and frames with 2+ faces never count. After 10 s paused, or
10 s with no face before the scan starts, it fails with "No face seen" or "More than one face".

**Expressions:** mask vertices that sit on a Vision landmark follow it exactly, so the mouth opens and the brows and
eyelids move.

## The mask

- **Source:** MediaPipe's canonical face (Apache-2.0, see THIRD_PARTY_NOTICES), decimated by `ml/scan_mesh.py` to
  160 vertices and 235 triangles, with eye and mouth holes. It's shipped as the generated `ScanMesh.swift`.
- **Vision → mesh map:** derived from data with `ml/scan_mesh.py --remap`. Both detectors were run on the parity faces;
  each Vision point takes the nearest MediaPipe vertex by majority vote (median error 0.037 IOD).
- **Per frame:**
  1. Rotate by the One-Euro-filtered yaw, pitch and roll: R = Ry · Rx · Rz.
  2. Fit scale + offset to the visible points (weighted least squares; visibility = facing², contour × 0.6).
  3. Pull the vertices onto their points; other vertices blend nearby residuals within σ = 1.4 cm.
  4. Cull triangles that face away.
- **Fill regions:** each triangle belongs to the pose that turns it toward the camera most (its gain at ±22° vs
  straight, margin 0.08), which gives 82 / 72 / 81 triangles. Because the regions come from the yaw sign, the mirrored
  display lights the correct cheek by construction.
- **Signs:** Vision's yaw and roll match ours. This was measured on the parity faces (nose offset and eye-line angle).
  The pitch sign is not measured yet; `ScanFrame.pitchSign` flips it if needed.

## Face print (unchanged math)

- The camera runs at 15 fps for the scan and embeds every frame.
- Only frames counted **during the straight hold** go into the template, which is the unit mean, exactly as before.
  At least 10 frames are needed.
- Side frames guide only: nothing yawed reaches the template until B2's pre-registered margin bar passes live.
- The scan's embeddings live in memory and are dropped when the scan ends.

## Privacy

- The camera image is drawn from the same data output the scan already reads: mirrored, monochrome and half size
  (Core Image), set as a plain layer's contents, and shown only until the sweep. Nothing is recorded, written or sent.
  There's no `AVCaptureVideoPreviewLayer`: with one on the session, the system's in-process object detection and our
  Vision requests deadlocked (the camera queue stuck on the first frame, and the main thread hung in `stopRunning`).
  `Camera.stop()` now runs `stopRunning` off the main thread too.
- DESIGN §7 is amended accordingly: the scan is the one place a camera image shows, and only while the mask forms.

## Power

The camera runs at 15 fps (it was 5) for about 6–10 s. A 60 Hz render timer runs only while the scan view animates,
and the camera layer is dropped after the sweep. Once the scan ends, nothing runs. Guard's power is unchanged.

## Reduce Motion

- The sweep becomes a 0.2 s cross-fade (the camera fades out while the mask fades in).
- The collapse becomes a fade.
- The mascot snaps between poses.
- The mask still tracks the head, because that's functional, not decoration.

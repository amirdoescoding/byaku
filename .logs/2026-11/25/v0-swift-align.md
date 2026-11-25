# PR3: Swift 5-point alignment (2026-11-25)

**What:** `similarity()` + `arcfaceTemplate` (Math), `Align.swift` (bilinear warp, Vision → 5 points, landmarks on existing rects),
`byaku align` parity check, the aligned live camera path (32BGRA), `byaku match` + `ml/score_segments.py`, and `convert_sface.py` now dumps YuNet
landmarks and a lossless sample.png.

**Results:** warp parity 1.00000; landmark parity FAIL vs 0.98 (reported only; annotated sample image); live bar v2 **PASS**, margin +0.228
(Python +0.633), with yaw −30° the weak spot; rails GPU 8 / ANE 17 / CPU 100 mW.

**Surprises:**
- vImage affine warp uses a bottom-left origin and +0.5 pixel centres, and its Lanczos kernel can't reach 0.99. A plain loop was simpler and exact.
- ImageIO and libjpeg decode the same JPEG ~3.5 levels apart, which alone costs ~0.01 cosine.
- Vision misses small faces in a 2048 px image. Vision confidence (~0.83 for a clear face) isn't on YuNet's scale, so the 0.9 cut copied
  into the pre-registration rejected every frame. It was amended before any scored data and documented.
- `uv run --active` recreated the repo-root `.venv`.

**Self-rating: 7/10.** The warp debugging was systematic (isolate the geometry, then the kernel, then the decode), and the pre-registration stayed
honest. Losses: copied the 0.9 cutoff without checking Vision's scale, which cost the user a run, and the landmark parity proxy turned out weak.

# v0 spike PR2: owner match (2026-11-25)

**What:** `ml/` uv tooling (fetch, convert, live scorer), `byaku embed`, `detect --embed`, and a power-script option for extra args.

**Answers on the M1:**
- (d) Owner match: SFace passes bar v2, with a margin of +0.633 and a threshold of 0.437. A photo of the owner matches, so the owner only suppresses and never disarms.
- Conversion: the onnx2torch route works, with parity 1.0000 across cv2, ORT, CoreML and Swift.
- Placement: `.all` put the head on the GPU, which cost +0.1 W. Switching to `.cpuAndNeuralEngine` fixed it. Embedding costs ~20–25 mW at 1 Hz.

**Surprises:**
- The first live run failed bar v1 because of labelling: the owner was in frame while holding stranger photos. A new bar was pre-registered and committed before the re-run.
- The powermetrics labels were swapped in the first paste. The GPU-burst signature identified which run was which.
- A shell `sed` commented out a closing brace, and the commit went through on a stale binary. Fixed with an amend; next time, chain the build so a failure stops the commit.

**Self-rating: 7/10.** The parity check and pass bar were solid, and the GPU placement finding was real. Losses: protocol v1 let labels get contaminated, and one broken commit slipped through.

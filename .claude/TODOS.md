# Backlog

## Next (pick one per PR)

- [ ] Stable self-signed identity so rebuilds keep the camera grant; later Developer ID + notarization + GitHub Release
- [ ] Verify the violet icon on a light menu bar (picks from the drawing appearance; spec wants `button.effectiveAppearance`)
- [ ] Optional: `scripts/power.sh 3 120 "1" "--embed ml/models/sface.mlpackage"` battery row (rails already show ~+20–25 mW)
- [ ] Yawed-face owner match in Swift (margin +0.228 vs Python +0.633; −30° worst). Try: landmarks on a tighter or upright crop, a different
  eye/nose mapping judged by pixel error on real yawed faces, or multi-pose enrollment. Pre-register before re-running.
- [ ] Verify Vision rev-3 yaw/pitch are continuous (turn head under `byaku detect`); tune the ±30°/±25° gaze gate with a second person
- [ ] Power: `scripts/power.sh` row with Guard on + one face (whole system); scroll baseline without the overlay
- [ ] Away: recorded message (mic permission, record/play/delete UI, file in Application Support); replaces the spoken line when set. Mockups first
- [ ] Away: covering the lens keeps (black) frames coming, so the stall check never fires; consider "too dark for N s → lock"
- [ ] Guard sound: replace `Submarine` once a licence-clean file exists

## Pipeline

[ ] Adaptive fps (burst on suspicion)

## Actions

- [ ] Opt-in auto-arm for Away (off by default; revisit after a week of manual use)

## App

- [ ] Menu-bar UI + settings (impeccable)
- [ ] [ ] Whitelist consent + privacy: store embeddings only (never photos), consent wording, per-person delete
- [ ] CI is live once this PR lands (build + test on macos-15); verify the first run

## ML (`ml/`)

- [ ] Gaze dataset + trained looking/not-looking classifier

## Ideas (later)

- Away "who looked" log: times and counts only, never images
- Frosted-glass Guard overlay (measure power first)
- Per-window blur of sensitive apps
- Context-aware strictness (home Wi-Fi vs train)

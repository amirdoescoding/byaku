# Backlog

## Next (pick one per PR)

- [ ] Away sound picker: Return doesn't pick a highlighted sound (custom menu-row views); click or VoiceOver press only
- [ ] Message panel: picking a sound while the panel plays the message stops it, but the panel's countdown sticks at 1 until Stop

- [x] Away sound picker: the siren is too alarming for some; let the user pick the sound (system sounds + computed siren). Mockups first
- [x] Away spoken line is too quiet next to the siren: raise the voice or duck the siren while it speaks
- [ ] Developer ID + notarization once there is a paid Apple account (release.yml keeps ad-hoc until then)
- [ ] Verify the violet icon on a light menu bar (picks from the drawing appearance; spec wants `button.effectiveAppearance`)
- [ ] Optional: `scripts/power.sh 3 120 "1" "--embed ml/models/sface.mlpackage"` battery row (rails already show ~+20–25 mW)
- [ ] Yawed-face owner match in Swift (margin +0.228 vs Python +0.633; −30° worst). Try: landmarks on a tighter or upright crop, a different
  eye/nose mapping judged by pixel error on real yawed faces, or multi-pose enrollment. Pre-register before re-running.
- [ ] Verify Vision rev-3 yaw/pitch are continuous (turn head under `byaku detect`); tune the ±30°/±25° gaze gate with a second person
- [ ] Power: `scripts/power.sh` row with Guard on + one face (whole system); scroll baseline without the overlay
- [x] Away: recorded message (mic permission, record/play/delete UI, file in Application Support); replaces the spoken line when set. Mockups first
- [ ] Away: covering the lens keeps (black) frames coming, so the stall check never fires; consider "too dark for N s → lock"
- [ ] Guard sound: replace `Submarine` once a licence-clean file exists

## Onboarding (after the MVP works end to end and the devops is done)

- [x] Step-by-step onboarding: real-menu tour with a coach bubble + mascot (PR12 `feat/onboarding`)
- [x] Closing video after setup: founder clip with lockup intro/outro (bundled, offline)
- [x] **PR B1: guided face scan** (`feat/face-scan`): live mesh mask, camera until the sweep, straight/left/right holds
- [x] PR B1 hardware QA: the user checked the scan on their Mac after the deadlock fix ("everything is good", 2026-11-27)
- [ ] Owner match after a rescan with a second person or photo (`byaku match`): the template now comes from ~15 frames in 1 s, not ~25 in 5 s
- [ ] **PR B2: multi-pose template**: pre-register the margin bar (owner 0° and ±25° vs strangers), compare straight-only vs
  multi-pose mean / per-pose max, verify live with a second person, then let side-hold prints into `ownerTemplate`
- [ ] Optional scan delight: the mascot copies the user's brow raise / blink (Vision brow + eye points are already tracked)
- [ ] Onboarding: VoiceOver pass on hardware (bubble announcements while the menu is open; video label)
- [ ] Onboarding: unvisited-row dots were cut (native NSMenu can't draw in its gutter); revisit only if the count isn't enough
- [ ] Install `impeccable-finish-reviewer` / `impeccable-documenter` agents (CLAUDE.md names them; they aren't installed)

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

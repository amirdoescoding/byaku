# Backlog

## Launch (2026-11-27)

Gate on the `v0.1.0-rc1` prerelease (download it in a browser on a new macOS user account):
- [ ] 1 Clean install: Open Anyway flow matches README step 3 exactly (macOS 15)
- [ ] 2 Onboarding end to end on the fresh account; founder video plays offline
- [ ] 3 Owner vs stranger (second person or photo) after a rescan: alerts on the stranger only
- [ ] 4 Away: stranger → siren + lock; revoke camera in System Settings while armed → locks
- [ ] 5 No network: `nettop -p Byaku` / `lsof -i -a -c Byaku` over ~5 min of Guard → none
- [ ] 6 No frames on disk: `sudo fs_usage -w -f filesys Byaku` → only prefs / Application Support / Keychain
- [ ] 7 Delete face data: one click, next launch asks for a scan
- [ ] 8 Power: `scripts/power.sh` Guard + one face on battery, ≤ ~1.5 W; record it
- [ ] 9 Open at login survives a reboot; Quit works
- [x] 10 Fonts in `assets/fonts` are all SIL OFL 1.1 (ship `OFL.txt` with the site)
- [x] Merge #15, tag `v0.1.0`, delete the rc release and tag; `curl -sIL …/releases/latest/download/Byaku-arm64.zip` → 200
- [x] PR B `feat/site`: shotgun → mockups → OK → Astro site → QA fixes → Vercel project (root `site`) + preview
- [ ] Site: merge PR B → production build on byaku-eight.vercel.app; check it loads and Download saves the zip
- [ ] Site: enable Web Analytics in the Vercel dashboard (byaku → Analytics → Enable); until then `/_vercel/insights/script.js` 404s
- [ ] Site: check by hand on a real iPhone: tap-to-gaze is weak (the scroll-velocity term dominates), pill feel, demo legibility at 375
- [ ] Site: battery FAQ says target only; add the measured number after launch test 8
- [ ] Site: custom domain later (optional); README + og meta point at byaku-eight.vercel.app

- [x] Launch film `video/` (PR C `feat/launch-video`): 2D Remotion, cut to EZ4U, final render `video/out/byaku-launch.mp4`
- [ ] Launch film: swap `ez4u.mp3` for the full-quality licensed download (current file is Epidemic's `fullmix_preview`)
- [x] Launch film: SFX synthesized locally (`video/scripts/sfx.py`, licence-clean; Epidemic MCP 401'd): click, slam ×2, rumble, wall-break crash, whoosh, wink ting
- [ ] Launch film: Epidemic MCP token rejected (401); re-issue or re-add without the Authorization header so it uses OAuth (needed for the full-quality track)
- [ ] Launch film: 9:16 cutdown for Reels/Shorts (optional)

## Next (pick one per PR)

- [ ] **Onboarding tour is guided, not click-anywhere** (rc1 QA, 2026-11-27): a stray click starts the founder video and the
  tour falls apart. Keep everything else the same. Light one menu row at a time, dim the rest; **Next** moves on; the last step
  is **Finish**, and only Finish plays the video.
- [ ] **Away message: hold to record** (rc1 QA): the fixed 8 s take confused a tester, who had to redo it. Press and hold
  Record, a live waveform plays while held, and releasing saves. Mockups first.
- [ ] Updates: no auto-update yet (users re-download). Decide with notarization: manual + GitHub release watch, or opt-in
  Sparkle (it would be the app's only network call, so it's against invariant 2 unless off by default)

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

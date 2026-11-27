# Restart

**2026-11-27**: PR C `feat/launch-video` is open with the launch film in `video/` (2D Remotion, light theme, 32.2 s). The user
approved v16 ("SIUUU BRAVO"); the final render is `video/out/byaku-launch.mp4` (gitignored). `cd video && npm i && npx remotion
studio` to edit; `npm run render` re-renders. The track (`video/public/audio/ez4u.mp3`, Epidemic EZ4U 32 s edit) is local only.

SFX are in: synthesized by `video/scripts/sfx.py` (`cd ml && uv run ../video/scripts/sfx.py`) into `video/public/audio/sfx/`,
cued by the `SFX` table in `Film.tsx`; the user auditioned each one. Next: merge PR C. The track is already 320 kbps (no swap needed);
Epidemic is dropped. Optional: 9:16 cutdown. Still open from PR B: merge the site, enable Analytics, check on a real iPhone. App: launch gate tests 1–9.

# PR C: launch film (`feat/launch-video`)

- Brief from a hard Q&A: ~30 s X/LinkedIn hero, upbeat, the mascot as a cheeky bodyguard narrator, same fonts.
- First pass: three.js clay mascot + modelled people as styleframes → rejected ("looks awful", people look cheap). Pivoted to
  2D Remotion after the user's reference trailer: kinetic type, mascot narrates, real product UI (site GuardScene reused).
- Iterated ~16 versions with the user: light theme; manga lettering (outline, impact bursts, katakana SFX, speed lines,
  anger vein); per-line entrances instead of the same hit every line; "mad mode" instead of a lock screen; charge + smash
  through the text; byaku shoves lines in and out from the sides; the real byaku menu opened by a cursor click.
- Music: Epidemic API keys returned 401 (Creator plan has MCP, not the API). "Die Happy" had a 3 s silence that read as a
  broken track → switched to EZ4U (32 s edit). Every hit is placed from librosa analysis (82.7 BPM, drop 13.13 s, downbeats);
  checked on the rendered audio.
- Self-rating: 7/10. The final cut is approved and beat-locked; it cost many render rounds that earlier mid-motion checks
  and asking about the music's shape before cutting would have saved. SFX and the licensed full-quality track are still open.

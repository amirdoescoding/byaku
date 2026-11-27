# byaku content plan (LinkedIn + X)

## Context
byaku is live: alpha release, site, repo and a 32 s launch film. Amir wants a social plan. Post 1 is the launch with a link. After that the mix is metrics, behind the scenes, what's next, face-tracking demos, and an IRL sketch. The copy follows his voice: lowercase, nonchalant, polite, dry. The content team is content-marketer, context-manager and content-quality-editor, with stop-slop on all copy.

## When to post (answer)
**Post on Saturday morning, not Friday evening.** Today is Black Friday. Feeds are full of deals, and people in Europe are offline on Friday night.
- **X: Saturday 28 Nov, 09:30 CET** (13:30 in Astana).
- **LinkedIn: Tuesday 1 Dec, 09:00 CET** would be best, because weekend reach on LinkedIn is low. If you want both out tomorrow, Saturday 09:30 CET still beats tonight.
- Reply to every comment for the first hour.

## Before posting
- Confirm the Epidemic Sound licence covers posting the film (the "EZ4U" track) on LinkedIn and X.
- Upload the film natively on both platforms (`video/out/byaku-launch.mp4`). Don't post it as a link.
- LinkedIn: put the link in the first comment. X: put the link in the post.

## Launch copy (final pass in your voice)
**LinkedIn** (the first line is a placeholder; swap in your real reason):
```
got tired of checking over my shoulder in cafés, so i built byaku.

it's a small macos menu bar app that uses your webcam to notice when someone else is looking at your screen.
- at your desk: a banner, a dim, or both
- away from it: a siren, and the mac locks

everything runs on your mac. no network calls, no frames saved, and you can delete your face data in one click.

it's open source and in alpha (apple silicon, macos 14+). not notarized yet, so macos will make you click open anyway once. sorry in advance.

the launch film was made with remotion and claude opus 5.5.

repo in the first comment. pls pls send feedback to my dms

p.s. detection runs at about 0.3 W on my m1
```
First comment: `repo: https://github.com/amirdoescoding/byaku` / `site: https://byaku-eight.vercel.app`

**X** (attach the film):
```
built a mac app that snitches on whoever's reading over your shoulder.

open source, runs on device. step away and it locks your mac instead.

https://github.com/amirdoescoding/byaku
```
Alternative X post: `someone is reading your screen right now. probably.` + the same body.

## 3-week calendar (X 3 a week, LinkedIn 2 a week)
| Day | Where | Pillar | Hook | Asset |
|---|---|---|---|---|
| Sat 28 Nov | X | launch | above | film |
| Tue 1 Dec | LI | launch | above | film |
| Wed 2 Dec | X | metrics | 0.3 W at 2 fps, measured on battery | `scripts/power.sh` output |
| Thu 3 Dec | LI | BTS | built on an m1 with no xcode | terminal recording |
| Fri 4 Dec | X | demo | friend leans in, banner fires | screen recording with face-box overlay |
| Mon 7 Dec | X | roadmap | why "open anyway" exists, notarizing next | Gatekeeper screenshot |
| Tue 8 Dec | LI | demo | away mode: siren and lock | phone shot of the Mac locking |
| Wed 9 Dec | X | IRL sketch | coworker sketch | 15–25 s, 9:16 |
| Thu 10 Dec | LI | metrics | face embedding costs 20–25 mW | per-rail chart |
| Fri 11 Dec | X | BTS | how the film was made (Remotion + Claude) | timeline screenshot |
| Mon 14 Dec | X | roadmap | trained gaze classifier replaces yaw/pitch thresholds | yaw/pitch plot |
| Tue 15 Dec | LI | BTS | SFX synthesized to the cut | waveform screenshot |
| Thu 17 Dec | LI | IRL sketch | café/barista sketch | 20–30 s, 1:1 |
| Fri 18 Dec | X | demo | owner stays clear, stranger triggers the dim | screen recording |

**Sketch ideas:**
1. Coworker leans over, banner fires, you say a flat "morning".
2. Barista glances over, violet mist, you close the lid.
3. You walk away, a friend sits down, siren, locked screen.

Get consent from everyone on camera.

**Never claim:** notarized, Intel/Windows support, any accuracy %, "trained gaze model", "zero battery". Always say "measured on an m1".

## Verified facts (cite only these)
- Apple silicon, macOS 14+. Alpha, MIT, ad-hoc signed (not notarized): first open needs "Open Anyway".
- Pipeline: ~640×480 camera at adaptive 1–5 fps (≈1 fps with only the owner, bursts to ≈5 on a new face) → Apple Vision on the Neural Engine → SFace owner match (CoreML, 1.25 ms/embed) → yaw/pitch heuristic → debounce (2 of last 3 frames, ≈2 s to fire).
- Power on one M1, whole-system on battery, 3×120 s runs: camera + Vision ≈0.3–0.4 W at 1–2 fps, ≈1 W at 5 fps. SFace at 1 Hz +20–25 mW. Iris mist 2–4 mW. Target ≤1.5 W.
- Privacy: on-device, no network calls, frames never saved, face data deletable in one click.
- Away: owner's face suppresses triggers but never disarms (photo-spoof defence); fails closed.
- Prior art to credit: EyesOff, Apple Vision, opencv_zoo SFace.
- Assets: `video/out/byaku-launch.mp4` (32 s, 1080p30), brand SVGs in `design/brand/final/`, site, repo.

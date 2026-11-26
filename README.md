# byaku

**Know when someone is reading over your shoulder.**

byaku is an open-source macOS menu-bar app. It watches your webcam for faces that aren't yours and are looking
at your screen. When it finds one, it reacts. Everything runs on your Mac, and no frame ever leaves it.

> Status: **pre-alpha**. Guard works end to end; Away mode and a signed release are next. See [Roadmap](#roadmap).

## Modes

**Guard**: you're at the computer. When someone else looks at your screen, byaku can:
- show a discreet banner
- dim the screen

**Away**: you stepped away. When anyone looks at your screen, byaku:
- plays a loud sound
- locks the computer

Everything is adjustable: which actions run, dim strength, sensitivity, and how long a look must last before
byaku reacts.

## How it works

```
camera (low res, 1–5 fps) → face detection → is it you? → is it looking at the screen? → debounce → action
```

1. **Face detection**: Apple Vision on the Neural Engine.
2. **Owner match**: you enroll your face once. byaku compares faces against a stored embedding (SFace).
3. **Gaze**: head yaw/pitch first. A small trained classifier comes later.
4. **Debounce**: a face must be seen looking for several frames before byaku reacts, which avoids flicker.

The design target is ≤ ~1.5 W of extra power while guarding. Details are in
[`.claude/ARCHITECTURE.md`](.claude/ARCHITECTURE.md).

## Privacy

- All processing is on-device. The app makes no network calls.
- Camera frames are processed in memory and never saved.
- Your face embedding stays on your Mac, and you can delete it any time.

## Roadmap

- [x] v0 spike: camera → face count in the terminal, with power measured
- [x] Owner enrollment
- [x] Gaze heuristic
- [x] Guard actions: banner, dim
- [ ] Away actions: sound, lock
- [x] Menu bar + settings
- [x] Build-from-source `.app` with Open at login
- [ ] Signed `.app` release
- [ ] Trained gaze classifier (`ml/`)

## Install

byaku isn't notarized yet, so you build it from source. It takes one script.

**You need**
- macOS 14 or later on **Apple silicon**. Building needs an arm64 Mac (the model converter pins torch 2.7.0, which has no Intel macOS build).
- Command Line Tools: `xcode-select --install` (full Xcode is not needed)
- [uv](https://docs.astral.sh/uv/): `brew install uv`

**Build and install**

```sh
git clone https://github.com/amirdoescoding/byaku.git
cd byaku
scripts/bundle.sh --install
```

This builds `Byaku.app`, signs it locally (ad-hoc), copies it to `~/Applications/Byaku.app`, and opens it. The first run
also downloads the SFace face model and converts it to Core ML. uv sets up Python 3.12, torch and coremltools for this
(about 650 MB in `ml/.venv`, a few minutes). Later builds skip that step. The network is only used at build
time. The app itself makes no network calls.

**First run**
1. Click the byaku icon in the menu bar, then **Set up face…**. Allow camera access when macOS asks, then look at the screen for 5 seconds.
2. Turn on **Guard**. Pick a **Mode** (Whisper, Iris, Shade, Awaken) and whether you want the banner and sound.
3. Optional: turn on **Open at login**. byaku then starts with your Mac, and Guard comes back on if it was on when you quit.

**Update**

```sh
git pull && scripts/bundle.sh --install
```

Each local build has a new signature, so macOS may ask for camera access again. Open at login, your face and your settings are kept.

**Uninstall** (in this order, so no stale login item is left behind)
1. In the byaku menu: turn off **Open at login**, click **Delete face data**, then **Quit byaku**.
2. Delete `~/Applications/Byaku.app`.
3. Optional cleanup: `tccutil reset Camera dev.byaku.app` and `defaults delete dev.byaku.app`.

**Troubleshooting**
- *"Not guarding: camera access denied"*: use **Open camera settings…** in the menu and allow byaku.
- *Open at login doesn't stick*: check System Settings → General → Login Items. byaku should be listed under "Open at Login".
- *"face model missing"*: run `scripts/bundle.sh --install` again from the repo; the model is built into the app.

## Development

See [`AGENTS.md`](AGENTS.md) for the stack, commands, invariants and workflow.

## Credits

- [Apple Vision](https://developer.apple.com/documentation/vision) for face detection
- [opencv_zoo SFace](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface) for face recognition
- [EyesOff](https://www.eyesoff.app/blog/how-eyesoff-spots-shoulder-surfers/) as prior art for the pipeline

## License

[MIT](LICENSE)

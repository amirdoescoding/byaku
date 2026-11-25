# byaku

**Know when someone is reading over your shoulder.**

byaku is an open-source macOS menu-bar app. It watches your webcam for faces that aren't yours and are looking
at your screen. When it finds one, it reacts. Everything runs on your Mac, and no frame ever leaves it.

> Status: **pre-alpha**. The design is done, the code is not. See [Roadmap](#roadmap).

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

- [ ] v0 spike: camera → face count in the terminal, with power measured
- [ ] Owner enrollment
- [ ] Gaze heuristic
- [ ] Guard actions: banner, dim
- [ ] Away actions: sound, lock
- [ ] Menu bar + settings
- [ ] Signed `.app` release
- [ ] Trained gaze classifier (`ml/`)

## Development

See [`AGENTS.md`](AGENTS.md) for the stack, commands, invariants and workflow.

## Credits

- [Apple Vision](https://developer.apple.com/documentation/vision) for face detection
- [opencv_zoo SFace](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface) for face recognition
- [EyesOff](https://www.eyesoff.app/blog/how-eyesoff-spots-shoulder-surfers/) as prior art for the pipeline

## License

[MIT](LICENSE)

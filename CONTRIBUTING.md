# Contributing to byaku

Thanks for helping. Bug reports, ideas and pull requests are all welcome.

## Before you start

byaku is a macOS menu-bar app for Apple silicon. It watches the webcam, and everything stays on the device. Read
[`AGENTS.md`](AGENTS.md) for the stack and the invariants. A change must not break them:

- Frames never leave the device and never touch disk.
- The app makes no network calls.
- Away mode fails closed.
- Power stays within the budget. If your change touches the pipeline, say what it costs and measure it with
  `scripts/power.sh`.

## Build from source

You need macOS 14 or later on Apple silicon, Command Line Tools (`xcode-select --install`) and
[uv](https://docs.astral.sh/uv/) (`brew install uv`).

```sh
git clone https://github.com/amirdoescoding/byaku.git
cd byaku
scripts/bundle.sh --install
```

The first run downloads the face model and converts it to Core ML. It takes a few minutes. Later builds skip that step.

## Run the tests

```sh
swift build
swift test
```

Changes to the detection pipeline also need a check on a real camera with a second person or a photo. Unit tests alone
don't count.

## Branches and pull requests

- One branch per feature: `feat/...`, `fix/...` or `chore/...`. Never commit to `main`.
- One pull request per feature. Keep it small.
- Use conventional commit prefixes: `feat:`, `fix:`, `docs:`, `chore:`.
- Don't commit models (`*.onnx`, `*.mlpackage`, `*.mlmodel`) or secrets.
- Say what you changed and how you checked it.

## The website

The landing page lives in `site/` (Astro). Run `cd site && npm install && npm run dev`.

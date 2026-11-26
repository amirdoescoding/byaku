#!/bin/sh
# Builds build/Byaku.app (arm64, ad-hoc signed). No Xcode needed. Run from anywhere.
#   scripts/bundle.sh --install   also copies it to ~/Applications and (re)opens it
set -eu
cd "$(dirname "$0")/.."
model=ml/models/sface.mlpackage
if [ ! -d "$model" ]; then  # first build only: uv fetches SFace and converts it (network here only; the app makes none)
    command -v uv >/dev/null || { echo "bundle: uv missing; brew install uv"; exit 1; }
    (cd ml && uv run convert_sface.py)
fi
swift build -c release
app=build/Byaku.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Byaku "$app/Contents/MacOS/"
cp app/Info.plist "$app/Contents/"
cp app/AppIcon.icns "$app/Contents/Resources/"
cp -R "$model" "$app/Contents/Resources/"
# Sign last so Info.plist and resources are sealed. Ad-hoc: TCC is tied to the cdhash, so a rebuild may re-prompt
# (tccutil reset Camera dev.byaku.app). No hardened runtime, so no camera entitlement is needed.
codesign --force --sign - "$app"
echo "built $app; run: open $app"
if [ "${1:-}" = "--install" ]; then
    # Quit only the installed app, by bundle id: a terminal `byaku detect` or power run keeps going.
    osascript -e 'if application id "dev.byaku.app" is running then tell application id "dev.byaku.app" to quit' >/dev/null 2>&1 || true  # unknown id on a first install: ignore
    sleep 1
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/Byaku.app"
    cp -R "$app" "$HOME/Applications/"
    open "$HOME/Applications/Byaku.app"
    echo "installed ~/Applications/Byaku.app"
fi

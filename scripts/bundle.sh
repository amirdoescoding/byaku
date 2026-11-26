#!/bin/sh
# Builds build/Byaku.app (arm64, ad-hoc signed). No Xcode needed. Run from anywhere.
set -eu
cd "$(dirname "$0")/.."
model=ml/models/sface.mlpackage
[ -d "$model" ] || { echo "bundle: $model missing; run (cd ml && uv run convert_sface.py)"; exit 1; }
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

#!/bin/sh
# Fails when a raw colour or animation timing appears outside Sources/Byaku/Tokens.swift (docs/designs/menubar.md §6).
cd "$(dirname "$0")/.." || exit 1
bad=$(grep -nE '0x[0-9A-Fa-f]{6}\b|#[0-9A-Fa-f]{6}\b|NSColor\((red|srgbRed|calibratedRed|deviceRed|white|calibratedWhite):|(duration|Duration) *[=:] *[0-9]|asyncAfter\(deadline: \.now\(\) \+ [0-9]' \
      Sources/Byaku/*.swift | grep -v '^Sources/Byaku/Tokens.swift:')
if [ -n "$bad" ]; then
  echo "check-ui: raw colour or timing outside Tokens.swift:"; echo "$bad"; exit 1
fi
echo "check-ui: ok"

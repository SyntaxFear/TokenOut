#!/bin/zsh
# Assembles dist/BurnBar.app from a release build and ad-hoc signs it.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "» building (release)…"
swift build -c release 2>&1 | tail -1
BIN=".build/release/BurnBar"
[[ -f "$BIN" ]] || { echo "binary not found: $BIN"; exit 1; }

if [[ ! -f Support/AppIcon.icns ]]; then
  echo "» generating app icon…"
  swift scripts/makeicon.swift
fi

APP="dist/BurnBar.app"
echo "» assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/BurnBar"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "» ad-hoc signing…"
codesign --force --deep -s - "$APP"
codesign --verify "$APP" && echo "✓ $APP ready"

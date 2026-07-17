#!/bin/zsh
# Assembles dist/BurnBar.app with Sparkle and signs it. Set SIGNING_IDENTITY
# to a Developer ID Application identity for distribution; defaults to ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
if [[ "$CONFIG" == "release" ]]; then
  BUILD_ARGS=(-c "$CONFIG" --arch arm64 --arch x86_64)
else
  BUILD_ARGS=(-c "$CONFIG")
fi

echo "» building (release)…"
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BIN="$BIN_DIR/BurnBar"
SPARKLE="$BIN_DIR/Sparkle.framework"
[[ -f "$BIN" ]] || { echo "binary not found: $BIN"; exit 1; }
[[ -d "$SPARKLE" ]] || { echo "framework not found: $SPARKLE"; exit 1; }

if [[ ! -f Support/AppIcon.icns ]]; then
  echo "» generating app icon…"
  swift scripts/makeicon.swift
fi

APP="dist/BurnBar.app"
echo "» assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/BurnBar"
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
chmod +x "$APP/Contents/MacOS/BurnBar"

if ! otool -l "$APP/Contents/MacOS/BurnBar" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP/Contents/MacOS/BurnBar"
fi

echo "» signing with $SIGNING_IDENTITY…"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP/Contents/Frameworks/Sparkle.framework"
  codesign --force --sign - "$APP"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" \
    "$APP/Contents/Frameworks/Sparkle.framework"
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
fi

codesign --verify --deep --strict --verbose=2 "$APP"
echo "✓ $APP ready"

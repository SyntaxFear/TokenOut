#!/bin/zsh
# Assembles dist/TokenOut.app with Sparkle and signs it. Set SIGNING_IDENTITY
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
BIN="$BIN_DIR/TokenOut"
SPARKLE="$BIN_DIR/Sparkle.framework"
RESOURCE_BUNDLE="$BIN_DIR/TokenOut_TokenOut.bundle"
# Universal (multi-arch) builds nest resources in Contents/Resources; debug
# single-arch builds keep them at the bundle root.
if [[ -d "$RESOURCE_BUNDLE/Contents/Resources" ]]; then
  RESOURCE_BUNDLE="$RESOURCE_BUNDLE/Contents/Resources"
fi
[[ -f "$BIN" ]] || { echo "binary not found: $BIN"; exit 1; }
[[ -d "$SPARKLE" ]] || { echo "framework not found: $SPARKLE"; exit 1; }
[[ -d "$RESOURCE_BUNDLE" ]] || { echo "resource bundle not found: $RESOURCE_BUNDLE"; exit 1; }
[[ -d "$RESOURCE_BUNDLE/Fonts" ]] || { echo "font resources not found: $RESOURCE_BUNDLE/Fonts"; exit 1; }

if [[ ! -f Support/AppIcon.icns ]]; then
  echo "» generating app icon…"
  swift scripts/makeicon.swift
fi

APP="dist/TokenOut.app"
echo "» assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/TokenOut"
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
# Flatten the SwiftPM resource bundle into Contents/Resources so codesign's
# resource seal covers it (SwiftPM's own Bundle.module accessor expects the
# bundle as a sibling of Contents/, which codesign then flags as unsealed).
ditto "$RESOURCE_BUNDLE/ProviderLogos" "$APP/Contents/Resources/ProviderLogos"
ditto "$RESOURCE_BUNDLE/BrandMark" "$APP/Contents/Resources/BrandMark"
ditto "$RESOURCE_BUNDLE/Fonts" "$APP/Contents/Resources/Fonts"
for lproj in es fr de pt ru ja zh hi ar; do
  ditto "$RESOURCE_BUNDLE/$lproj.lproj" "$APP/Contents/Resources/$lproj.lproj"
done
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
chmod +x "$APP/Contents/MacOS/TokenOut"

if ! otool -l "$APP/Contents/MacOS/TokenOut" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP/Contents/MacOS/TokenOut"
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

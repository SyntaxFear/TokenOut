#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

APP="dist/TokenOut.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="dist/TokenOut-${VERSION}.dmg"
RW_DMG="$(mktemp -u /tmp/TokenOut-rw.XXXXXX).dmg"
STAGE="$(mktemp -d /tmp/TokenOut-stage.XXXXXX)"
MOUNT=""
BACKGROUND="$STAGE/.background/background.png"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Levan Parastashvili (CNH4KYRW44)}"

cleanup() {
  if [[ -n "$MOUNT" ]]; then
    hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGE" "$RW_DMG"
}
trap cleanup EXIT

[[ -d "$APP" ]] || { echo "Missing $APP. Run scripts/bundle.sh first."; exit 1; }

mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/TokenOut.app"
ln -s /Applications "$STAGE/Applications"

swift scripts/makedmgbackground.swift "$BACKGROUND"

hdiutil create -volname TokenOut -srcfolder "$STAGE" -fs HFS+ -ov -format UDRW "$RW_DMG" >/dev/null
MOUNT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen | tail -1 | awk -F '\t' '{print $NF}')"
[[ -d "$MOUNT" ]] || { echo "Unable to mount writable DMG."; exit 1; }

osascript <<'APPLESCRIPT'
tell application "Finder"
  tell disk "TokenOut"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 760, 500}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 104
    set text size of viewOptions to 14
    set background color of viewOptions to {63222, 63222, 63222}
    set background picture of viewOptions to file ".background:background.png"
    set position of item "TokenOut.app" of container window to {176, 220}
    set position of item "Applications" of container window to {484, 220}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

cp "$APP/Contents/Resources/AppIcon.icns" "$MOUNT/.VolumeIcon.icns"
[[ -f "$MOUNT/.VolumeIcon.icns" ]] || { echo "Unable to copy volume icon."; exit 1; }
/Applications/Xcode.app/Contents/Developer/usr/bin/SetFile -a C "$MOUNT"
[[ -f "$MOUNT/.VolumeIcon.icns" ]] || { echo "Volume icon was not preserved on writable image."; exit 1; }
sync
hdiutil detach "$MOUNT" >/dev/null
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG" >/dev/null

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG"
fi

hdiutil verify "$DMG" >/dev/null
codesign --verify --verbose=2 "$DMG"
cp "$DMG" dist/TokenOut.dmg
echo "✓ $DMG"

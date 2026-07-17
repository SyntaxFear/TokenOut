#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

DMG="${1:-dist/BurnBar-1.0.0.dmg}"
PROFILE="${NOTARY_PROFILE:-BurnBarNotary}"

[[ -f "$DMG" ]] || { echo "Missing $DMG"; exit 1; }

echo "» submitting $DMG with Keychain profile $PROFILE…"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"
echo "✓ notarized and stapled: $DMG"

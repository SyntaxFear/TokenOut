#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

DMG="${1:-dist/TokenOut-1.0.0.dmg}"
PROFILE="${NOTARY_PROFILE:-TokenOutNotary}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-CNH4KYRW44}"

[[ -f "$DMG" ]] || { echo "Missing $DMG"; exit 1; }

if [[ -n "$APPLE_ID" && -n "$APPLE_APP_SPECIFIC_PASSWORD" ]]; then
  echo "» submitting $DMG with Apple notarization credentials…"
  xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
else
  echo "» submitting $DMG with Keychain profile $PROFILE…"
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
fi
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"
ditto "$DMG" dist/TokenOut.dmg
echo "✓ notarized and stapled: $DMG"
echo "✓ latest-download alias refreshed: dist/TokenOut.dmg"

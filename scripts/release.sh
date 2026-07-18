#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)}"
PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Levan Parastashvili (CNH4KYRW44)}"

[[ "$VERSION" == "$PLIST_VERSION" ]] || {
  echo "Version mismatch: requested $VERSION but Support/Info.plist contains $PLIST_VERSION"
  exit 1
}

echo "» building TokenOut $VERSION…"
SIGNING_IDENTITY="$SIGNING_IDENTITY" ./scripts/bundle.sh
SIGNING_IDENTITY="$SIGNING_IDENTITY" ./scripts/create-dmg.sh
./scripts/notarize.sh "dist/TokenOut-${VERSION}.dmg"
./scripts/publish-appcast.sh "$VERSION"

echo "✓ TokenOut $VERSION is signed, notarized, stapled, and ready for GitHub"
echo "  versioned: dist/TokenOut-${VERSION}.dmg"
echo "  latest:    dist/TokenOut.dmg"
echo "  appcast:   website/public/appcast.xml"

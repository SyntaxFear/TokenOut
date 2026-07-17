#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
DMG="dist/BurnBar-${VERSION}.dmg"
RELEASE_DIR="releases"
APPCAST_TOOL=".build/artifacts/sparkle/Sparkle/bin/generate_appcast"
DOWNLOAD_PREFIX="https://github.com/SyntaxFear/BurnBar/releases/download/v${VERSION}/"

[[ -f "$DMG" ]] || { echo "Missing $DMG"; exit 1; }
[[ -x "$APPCAST_TOOL" ]] || { echo "Missing Sparkle generate_appcast tool. Run swift build first."; exit 1; }

mkdir -p "$RELEASE_DIR"
cp "$DMG" "$RELEASE_DIR/BurnBar-${VERSION}.dmg"
cp Support/ReleaseNotes.md "$RELEASE_DIR/BurnBar-${VERSION}.md"

"$APPCAST_TOOL" \
  --account dev.burnbar.mac \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  --link https://burnbar.scrubmac.app \
  --embed-release-notes \
  "$RELEASE_DIR"

cp "$RELEASE_DIR/appcast.xml" website/public/appcast.xml
echo "✓ signed appcast copied to website/public/appcast.xml"

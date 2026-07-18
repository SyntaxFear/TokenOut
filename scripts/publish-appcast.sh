#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
DMG="dist/TokenOut-${VERSION}.dmg"
RELEASE_DIR="releases"
APPCAST_TOOL=".build/artifacts/sparkle/Sparkle/bin/generate_appcast"
DOWNLOAD_PREFIX="https://github.com/SyntaxFear/TokenOut/releases/download/v${VERSION}/"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-dev.tokenout.mac}"

[[ -f "$DMG" ]] || { echo "Missing $DMG"; exit 1; }
[[ -x "$APPCAST_TOOL" ]] || { echo "Missing Sparkle generate_appcast tool. Run swift build first."; exit 1; }

mkdir -p "$RELEASE_DIR"
cp "$DMG" "$RELEASE_DIR/TokenOut-${VERSION}.dmg"
cp Support/ReleaseNotes.md "$RELEASE_DIR/TokenOut-${VERSION}.md"

APPCAST_ARGS=(
  --download-url-prefix "$DOWNLOAD_PREFIX"
  --link https://tokenout.scrubmac.app
  --full-release-notes-url "https://tokenout.scrubmac.app/releases"
  --embed-release-notes
)

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  print -rn -- "$SPARKLE_PRIVATE_KEY" | "$APPCAST_TOOL" --ed-key-file - "${APPCAST_ARGS[@]}" "$RELEASE_DIR"
else
  "$APPCAST_TOOL" --account "$SPARKLE_ACCOUNT" "${APPCAST_ARGS[@]}" "$RELEASE_DIR"
fi

cp "$RELEASE_DIR/appcast.xml" website/public/appcast.xml
echo "✓ signed appcast copied to website/public/appcast.xml"

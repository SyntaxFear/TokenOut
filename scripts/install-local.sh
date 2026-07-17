#!/bin/zsh
# Installs dist/BurnBar.app into /Applications and launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -d dist/BurnBar.app ]] || { echo "run scripts/bundle.sh first"; exit 1; }

pkill -x BurnBar 2>/dev/null || true
sleep 0.5
ditto --rsrc dist/BurnBar.app /Applications/BurnBar.app
open /Applications/BurnBar.app
echo "✓ BurnBar installed and launched — look at your menu bar 🔥"

#!/bin/zsh
# Installs dist/TokenOut.app into /Applications and launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -d dist/TokenOut.app ]] || { echo "run scripts/bundle.sh first"; exit 1; }

pkill -x TokenOut 2>/dev/null || true
sleep 0.5
# Clean replace: ditto into an existing bundle can leave stale files behind.
rm -rf /Applications/TokenOut.app
ditto --rsrc dist/TokenOut.app /Applications/TokenOut.app
open /Applications/TokenOut.app
echo "✓ TokenOut installed and launched — look at your menu bar 🔥"

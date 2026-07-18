#!/bin/zsh
# How many times each release DMG has been downloaded (GitHub asset counters —
# counts only, no information about who). PostHog `download_requested` adds
# button-level counts once the site is deployed with POSTHOG_PROJECT_TOKEN.
set -euo pipefail
gh api repos/SyntaxFear/TokenOut/releases --jq '
  .[] | "\(.tag_name)  (\(.published_at[:10]))",
  (.assets[] | "  \(.name): \(.download_count) downloads")'

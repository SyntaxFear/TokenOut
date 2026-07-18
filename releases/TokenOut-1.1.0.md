# TokenOut 1.1.0

The rename release — BurnBar is now TokenOut — plus a major round of features and fixes.

## New

- **New identity**: TokenOut name, token-ring app icon, and menu bar mark. Existing BurnBar data and settings migrate automatically.
- **Share cards**: export your usage (today / week / 30 days, per provider or combined) as a polished PNG — AirDrop, Messages, copy, or save. Includes daily average, peak day, active days, per-provider share, and the models you used.
- **Pace metrics**: every limit window shows a human refill countdown with the exact reset time, plus how far you're over or under pace ("14% in reserve" / "16% over pace").
- **Customizable menu bar**: combine icon, usage gauge, percentage, per-provider split, today's tokens, and today's cost.
- **Appearance**: system/light/dark theme, four text sizes, 12 bundled Google Fonts, and 10 interface languages with live switching.
- **Right-click menu** on the menu bar icon: show usage, refresh, share, settings, quit.
- **Redesigned Settings** with a native sidebar layout, and a combined six-tile metrics grid per provider.

## Fixed

- Pricing audit against current Anthropic and OpenAI rates: correct gpt-5.3-codex pricing, Sonnet 5 introductory-pricing cutover by usage date, and no more double-counting of resumed Claude Code sessions.
- Rate-limit (HTTP 429) handling with Retry-After support — no more spurious "Some updates failed" while data is fresh.
- Popover sizes exactly to its content, stays open while you adjust Settings, and collapse animations are smooth.
- Menu bar label updates reliably.

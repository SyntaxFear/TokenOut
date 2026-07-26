# Changelog

All public TokenOut releases are documented here and at [tokenout.scrubmac.app/releases](https://tokenout.scrubmac.app/releases).

## [1.2.0] - 2026-07-26

### Added

- Compact provider cards now show both the 5-hour and tightest weekly limits.
- A concise Today row groups each provider's token total and API-equivalent value.
- Providers expand independently into the complete limits, breakdowns, and history view.

### Improved

- Reworked quota, breakdown, and chart colors around neutral adaptive tones; orange and red are now reserved for attention states.
- Increased compact-label legibility and replaced tiny all-caps labels with sentence case.
- Added reduced-motion-aware, critically damped disclosure animations.

## [1.0.0] - 2026-07-18

### Added

- Native macOS menu bar monitoring for Claude Code and Codex.
- Live usage windows, refill times, local token totals, cost estimates, daily charts, and provider breakdowns.
- Used and remaining percentage modes across the menu bar and popover.
- Configurable display sections, refresh cadence, alerts, launch at login, themes, text sizes, fonts, and ten languages.
- Shareable usage cards for today, this week, and the last 30 days.
- Universal Apple silicon and Intel packaging, Developer ID signing, Apple notarization, and signed Sparkle updates.

### Privacy

- TokenOut stores preferences and derived usage history locally.
- No TokenOut account, advertising SDK, provider-usage telemetry, or cloud sync.
- One anonymous first-launch event records only app version, build, macOS version, and processor architecture.

[1.2.0]: https://github.com/SyntaxFear/TokenOut/releases/tag/v1.2.0
[1.0.0]: https://github.com/SyntaxFear/TokenOut/releases/tag/v1.0.0

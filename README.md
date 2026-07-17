# BurnBar 🔥

**Your token burn, live in the menu bar.** A native macOS app that tracks usage,
rate-limit windows, and API-equivalent cost across AI coding tools.

| Provider | Limits | Tokens & cost |
|---|---|---|
| **Claude Code** | 5-hour session, weekly, per-model scoped windows (live from the official usage endpoint) | Local transcript parsing with per-model pricing, incl. 5m/1h cache-write rates |
| **Codex** | Session / weekly / monthly rate windows (live from the endpoint Codex itself uses) | Plan badge |
| **Antigravity** | Not exposed locally by Google — activity stats instead | Sessions, turns, estimated tokens from local conversation DBs |

The menu bar shows a literal *burn bar*: flame + draining gauge + percent for the
**tightest** window across enabled tools (configurable). Amber at 80%, red at 95%,
notifications at both thresholds, refill countdowns everywhere.

## Privacy

Everything stays on this Mac. BurnBar reads each tool's own local state
(Claude Code's Keychain item and `~/.claude/projects` transcripts, `~/.codex/auth.json`,
`~/.gemini/antigravity` conversation DBs) and talks **only** to each provider's own API
with your existing sign-in. Credentials are never written, stored, or sent anywhere else.
No analytics, no telemetry, no accounts.

macOS shows one Keychain prompt on first run ("BurnBar wants to access
'Claude Code-credentials'") — click **Always Allow**.

## Build & install (local)

```sh
swift test               # 28 tests
./scripts/bundle.sh      # release build → dist/BurnBar.app (ad-hoc signed)
./scripts/install-local.sh   # → /Applications/BurnBar.app + launch
```

Dev utilities:

```sh
swift run BurnBarProbe all   # print raw usage-endpoint responses + decoded windows
swift scripts/makeicon.swift # regenerate Support/AppIcon.icns
```

## Architecture

SwiftPM, three targets: `BurnBarCore` (normalized models, pricing, store, refresh policy —
pure logic, fully tested), `BurnBarProviders` (one folder per tool conforming to
`UsageProvider`), `BurnBar` (SwiftUI `MenuBarExtra` app). Adding a provider touches zero
UI code: conform to `UsageProvider`, append to the registry in `AppState`.

Design docs: [spec](docs/superpowers/specs/2026-07-17-burnbar-design.md) ·
[phase 1 plan](docs/superpowers/plans/2026-07-17-burnbar-phase1.md) ·
[Antigravity research](docs/providers/antigravity.md)

## Roadmap (phase 2 — public release)

Blocked on an Apple Developer account: Developer ID signing + notarization, DMG,
Sparkle auto-updates, Ed25519 offline licensing + trial, landing page (burnbar.dev).
Backlog: Cursor/Copilot/Gemini CLI providers, usage history charts, widgets.

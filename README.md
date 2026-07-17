# BurnBar

**Know your AI burn before limits hit.** BurnBar is a private native macOS menu bar app for tracking usage, rate-limit windows, tokens, and API-equivalent cost across AI coding tools.

[Website](https://burnbar.scrubmac.app) | [Download](https://github.com/SyntaxFear/BurnBar/releases/latest/download/BurnBar.dmg) | [Privacy](https://burnbar.scrubmac.app/privacy)

## Supported providers

| Provider | Limits | Local activity |
|---|---|---|
| **Claude Code** | Live session, weekly, and scoped windows from Claude Code's official usage endpoint | Transcript tokens, model breakdowns, and cost estimates |
| **Codex** | Live primary and secondary rate-limit windows | Local rollout history and plan details |
| **Antigravity** | Google does not expose a local quota signal | Sessions, turns, daily activity, and estimated local tokens |

The menu bar can show the tightest enabled limit, one provider, or compact readings for every provider. The popover includes configurable combined totals, provider details, breakdowns, daily charts, refill countdowns, refresh cadence, and notification thresholds.

Currency precision is visually quieter throughout the app: cents in values such as `$5125.33` are rendered smaller, while non-currency decimals such as `5.1M` tokens remain full-sized.

## Privacy

BurnBar reads each tool's existing local state and contacts only that provider's official service when a live quota refresh is available. It does not include analytics, telemetry, advertising SDKs, a BurnBar account, or cloud sync.

Claude Code credentials remain in Claude Code's original Keychain item. When Claude rotates its OAuth refresh token, BurnBar persists the rotated credential back to that item so both apps remain signed in. macOS may show a Keychain access prompt on first use.

## Requirements

- macOS 14 or later
- Apple silicon or Intel Mac
- At least one supported tool installed locally

## Build and test

```sh
swift test
./script/build_and_run.sh --verify
```

The production bundle is universal and embeds Sparkle:

```sh
SIGNING_IDENTITY='Developer ID Application: Levan Parastashvili (CNH4KYRW44)' ./scripts/bundle.sh
./scripts/create-dmg.sh
```

Notarization uses a `notarytool` Keychain profile:

```sh
xcrun notarytool store-credentials BurnBarNotary
NOTARY_PROFILE=BurnBarNotary ./scripts/notarize.sh
./scripts/publish-appcast.sh 1.0.0
```

Developer utilities:

```sh
swift run BurnBarProbe all
swift scripts/makeicon.swift
```

## Website

The Next.js site lives in `website/`.

```sh
cd website
npm install
npm run dev
npm run build
```

It includes metadata, structured data, Open Graph artwork, `robots.txt`, `sitemap.xml`, `llms.txt`, a privacy page, and the signed Sparkle appcast endpoint.

## Architecture

The Swift package has three primary targets:

- `BurnBarCore`: normalized models, formatting, pricing, history, store, and refresh policy.
- `BurnBarProviders`: provider implementations for Claude Code, Codex, and Antigravity.
- `BurnBar`: the SwiftUI `MenuBarExtra` application, settings, notifications, and Sparkle updater.

Design and provider notes are available in [the product spec](docs/superpowers/specs/2026-07-17-burnbar-design.md), [the phase-one plan](docs/superpowers/plans/2026-07-17-burnbar-phase1.md), and [Antigravity research](docs/providers/antigravity.md).

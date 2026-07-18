# TokenOut

**Claude and Codex. One clear view.** TokenOut is a private native macOS menu bar app for tracking Claude Code and Codex usage, rate-limit windows, tokens, and API-equivalent cost.

[Website](https://tokenout.scrubmac.app) | [Download](https://tokenout.scrubmac.app/download) | [Releases](https://tokenout.scrubmac.app/releases) | [Privacy](https://tokenout.scrubmac.app/privacy)

## Supported providers

| Provider | Limits | Local activity |
|---|---|---|
| **Claude Code** | Live session, weekly, and scoped windows from Claude Code's official usage endpoint | Transcript tokens, model breakdowns, and cost estimates |
| **Codex** | Live primary and secondary rate-limit windows | Local rollout history and plan details |
| **Antigravity** | Google does not expose a local quota signal | Sessions, turns, daily activity, and estimated local tokens |

The menu bar can show the tightest enabled limit, one provider, or compact readings for every provider. The popover includes configurable combined totals, provider details, breakdowns, daily charts, refill countdowns, refresh cadence, and notification thresholds.

Currency precision is visually quieter throughout the app: cents in values such as `$5125.33` are rendered smaller, while non-currency decimals such as `5.1M` tokens remain full-sized.

## Privacy

TokenOut reads each tool's existing local state and contacts only that provider's official service when a live quota refresh is available. Provider usage history stays local. TokenOut sends one anonymous first-launch event containing only app version, build, macOS version, and processor architecture; it has no advertising SDK, TokenOut account, or cloud sync.

Claude Code credentials remain in Claude Code's original Keychain item. When Claude rotates its OAuth refresh token, TokenOut persists the rotated credential back to that item so both apps remain signed in. macOS may show a Keychain access prompt on first use.

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
xcrun notarytool store-credentials TokenOutNotary
NOTARY_PROFILE=TokenOutNotary ./scripts/notarize.sh
./scripts/publish-appcast.sh 1.0.0
```

Or run the complete local release pipeline:

```sh
./scripts/release.sh 1.0.0
```

The manual GitHub Actions release workflow requires these repository secrets:

- `MACOS_CERTIFICATE_P12`: base64-encoded Developer ID Application `.p12`.
- `MACOS_CERTIFICATE_PASSWORD`: password used when exporting that certificate.
- `APPLE_ID`: Apple developer account email used for notarization.
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for `notarytool`.
- `SPARKLE_PRIVATE_KEY`: exported Sparkle EdDSA private key.

The workflow tests the app, builds a universal Developer ID-signed DMG, notarizes and staples it, generates the signed appcast, updates the website feed, uploads both versioned and stable download filenames, and publishes the GitHub release. Release history is maintained in [CHANGELOG.md](CHANGELOG.md).

Developer utilities:

```sh
swift run TokenOutProbe all
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

It includes canonical metadata, SoftwareApplication structured data, Open Graph artwork, branded icons and manifest, `robots.txt`, `sitemap.xml`, `llms.txt`, `llms-full.txt`, privacy and release-history pages, and the signed Sparkle appcast endpoint.

Analytics definitions and reporting commands are documented in [docs/analytics.md](docs/analytics.md).

## Architecture

The Swift package has three primary targets:

- `TokenOutCore`: normalized models, formatting, pricing, history, store, and refresh policy.
- `TokenOutProviders`: provider implementations for Claude Code, Codex, and Antigravity.
- `TokenOut`: the SwiftUI `MenuBarExtra` application, settings, notifications, and Sparkle updater.

Design and provider notes are available in [the product spec](docs/superpowers/specs/2026-07-17-tokenout-design.md), [the phase-one plan](docs/superpowers/plans/2026-07-17-tokenout-phase1.md), and [Antigravity research](docs/providers/antigravity.md).

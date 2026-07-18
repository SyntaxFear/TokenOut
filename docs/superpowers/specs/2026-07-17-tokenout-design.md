# TokenOut — Design Spec

**Date:** 2026-07-17
**Status:** Approved scope (Claude Code + Codex + Antigravity, native SwiftUI, product from day one)
**Phase 1 (current):** complete local-use app — all three providers, full UI, ad-hoc signed, installed on the dev Mac. **Licensing is deferred to the public phase** (user decision 2026-07-17), along with Sparkle, notarization/DMG, and the landing page, which unlock once the user provides their Apple Developer account.
**Name:** TokenOut — verified 2026-07-17: tokenout.app belongs to an unrelated drink-tracker app; tokenout.com registered-but-dormant since 2015; **tokenout.dev appears available**. Distribution is direct (notarized DMG), not App Store, so the collision is tolerable. Formal trademark diligence is a pre-launch task; renaming is cheap until launch.

## 1. Product

A macOS menu bar app that shows live usage, rate-limit windows, and token totals for AI coding tools. v1 tracks **Claude Code**, **Codex**, and **Antigravity**. Sold as a one-time license with a 7-day trial. The product keeps every important limit visible in one compact menu bar view.

- macOS 14+ (Apple Silicon + Intel universal binary)
- Menu-bar-only app (`LSUIElement`), no Dock icon
- Privacy story: all usage data stays on-device; credentials are read locally and only ever sent to each provider's own official API; the only TokenOut server traffic is license validation and update checks
- Price ballpark at launch: $9 solo / $15 all-tools (final call later; not a build blocker)

## 2. Architecture

Native SwiftUI, Swift 6, structured concurrency. SwiftPM package assembled into `TokenOut.app` by a bundling script (fully headless builds; no `.xcodeproj`). Migrate to XcodeGen only if/when widgets or App Store distribution force it.

SwiftPM targets:

| Target | Purpose |
|---|---|
| `TokenOutCore` | Models, `UsageProvider` protocol, refresh engine, stores, license verifier. Pure logic, no UI, fully unit-testable. |
| `TokenOutProviders` | One folder per provider (Claude, Codex, Antigravity). Depends on Core only. |
| `TokenOut` (app) | MenuBarExtra UI, popover, settings, notifications, onboarding. |

### Provider abstraction (the scalability requirement)

```swift
protocol UsageProvider: Sendable {
    static var id: ProviderID { get }
    var displayName: String { get }
    func detectInstallation() async -> Bool          // is the tool on this Mac?
    func fetchUsage() async throws -> UsageSnapshot   // normalized result
}
```

`UsageSnapshot` is the normalized model the UI consumes — the UI never knows provider specifics. Adding Cursor/Copilot later = one new folder + one registry line, zero UI changes.

```
UsageSnapshot
├── providerID, fetchedAt, accountLabel?
├── windows: [LimitWindow]        // label, usedFraction, resetsAt, kind (.session/.weekly/.credits)
├── tokens: TokenTotals?          // today / this week, per-model breakdown
├── costEstimate: Money?          // from bundled pricing table
└── detail: [DetailLine]          // provider-specific extras, rendered generically
```

Per-provider health: `ProviderStatus = .ok | .stale(since:) | .signedOut(help:) | .unsupported(reason:)`. Errors degrade a card, never crash the bar.

### Refresh engine

- Per-provider cadence: 60 s while any window ≥ 50 % used, otherwise 5 min; jitter ±10 %
- Exponential backoff on failures (max 15 min), immediate refresh on wake (`NSWorkspace` notifications) and on manual refresh
- Last snapshots persisted to Application Support so relaunch shows data instantly

## 3. Providers (v1)

### Claude Code
- **Credentials:** macOS Keychain item `Claude Code-credentials` (primary — confirmed present on this machine; file `~/.claude/.credentials.json` as fallback). TokenOut normally reads it; when Anthropic rotates a refresh token, TokenOut uses Claude Code's scope/locking contract and writes the complete rotated credential back to that same source so the CLI is not invalidated. First Keychain access triggers a one-time macOS permission prompt — onboarding explains it.
- **Limits:** `GET https://api.anthropic.com/api/oauth/usage` with the OAuth bearer token → 5-hour session window + weekly limits with utilization and reset timestamps.
- **401 handling:** attempt token refresh against the public Claude Code OAuth token endpoint (same client id the CLI uses; refreshed token kept in memory only). If refresh fails → `.signedOut("Open Claude Code and run /login")`.
- **Token/cost stats:** parse `~/.claude/projects/**/*.jsonl` transcripts (`message.usage` fields: input, output, cache read/write) → today/this-week totals and cost via a bundled pricing table (updatable with each app release). Parser tolerates schema drift: unknown fields ignored, entries without usage skipped.

### Codex
- **Credentials:** `~/.codex/auth.json` (OpenAI OAuth tokens + account id; confirmed present on this machine). Refresh flow on 401 via OpenAI's token endpoint.
- **Limits:** ChatGPT backend usage endpoint (the one Codex itself uses) → primary/secondary rate windows (5 h + weekly) with percent used and reset times. Exact response shape verified during build via live smoke test; recorded as fixtures.
- Plans without usage data → `.unsupported` with explanatory card.

### Antigravity
- Most research-heavy; **timeboxed spike first** (½ day): map `~/.antigravity` and `~/Library/Application Support/Antigravity` (both confirmed present) for transcripts, quota state, and Google OAuth material.
- Ship: local transcript/turn stats at minimum; Gemini quota via Google's cloudcode endpoint if credentials are accessible. Clearly labeled partial support if quota is unreachable. Spike findings recorded in `docs/providers/antigravity.md`.

## 4. UI

- **Menu bar:** TokenOut mark + a compact usage gauge + optional percent. Shows the *tightest* window across enabled providers by default; configurable to pin one provider. Color: normal → amber ≥ 80 % → red ≥ 95 %.
- **Popover:** one card per enabled provider — session window bar with % and "resets in H:MM", weekly bar, tokens today, est. cost, status badge. Footer: Refresh all · Settings · Quit.
- **Settings window:** providers on/off · menu bar metric picker · refresh interval · warning thresholds + notification toggle · launch at login (`SMAppService`) · license status/activation.
- **Notifications:** `UNUserNotificationCenter` alerts at 80 % and 95 % per window, debounced once per reset cycle.
- **Onboarding (first launch):** what TokenOut reads and why, Keychain prompt explanation, provider auto-detection, trial start.

## 5. Licensing (sub-project 2)

- **Keys:** Ed25519-signed license payload (email hash, tier, seats, issue date), verified **offline** in-app with the embedded public key. No account, no subscription.
- **Server (Vercel + Supabase):** `/api/trial/start`, `/api/license/activate` (device binding, seat limit), `/api/license/deactivate`, `/api/validate`. Offline grace: app works without network once activated.
- **Trial:** 7 days from first launch; local record + server echo when online to resist clock tampering. Expiry pauses tracking behind the activation screen (nothing is deleted).
- **Payments:** provider decision deferred (Paddle vs Lemon Squeezy — merchant-of-record preferred for VAT). Day-one sales work via manual key issuance CLI (`tokenout-keygen`).

## 6. Updates & distribution (sub-project 3)

- Sparkle 2 via SPM; EdDSA-signed appcast hosted on the site (Vercel)
- Hardened runtime, Developer ID signing + notarization (**needs the user's Apple Developer account — collected at the end**), styled DMG with `/Applications` symlink
- No App Sandbox (the entire product reads other tools' local state); documented in the privacy page

## 7. Landing page (sub-project 4)

Next.js on Vercel sharing the license API. Built after the app works. Out of v1 build scope.

## 8. Testing

- **Unit (Core/Providers):** transcript parser against fixtures; window math (reset countdowns, tightest-window selection, threshold crossings); API decoders against recorded JSON fixtures; license verifier (valid / tampered / expired / wrong-key).
- **Live smoke:** all three tools are installed on the dev Mac with real data — a manual flag runs providers against reality and records sanitized fixtures.
- **UI verify:** run the built app, screenshot menu bar + popover before handover.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Undocumented usage endpoints change | Provider abstraction + `.stale`/`.unsupported` degradation + fast Sparkle updates |
| Name collision (drink app owns tokenout.app) | Different category + direct distribution; trademark diligence before launch |
| Keychain ACL prompt scares users | Onboarding explains it before the prompt appears |
| Apple Developer account needed | Only blocks distribution, not development; requested at the end |

## 10. Build order

**Phase 1 — local use (current phase):**
1. **App core + Claude provider** — end-to-end: real data in the menu bar
2. **Codex provider**
3. **Antigravity spike + provider**
4. **Local ship** — onboarding polish, app icon, ad-hoc signing, install on the dev Mac

**Phase 2 — public (blocked on Apple Developer account):**
5. **Licensing** (Ed25519 verifier + trial + keygen CLI + Vercel/Supabase API)
6. **Sparkle + Developer ID signing/notarization + DMG**
7. **Landing page**

Each step leaves a working app.

## Out of scope (v2 backlog)

Widgets/appex, iOS companion, multi-account per provider, team dashboards, additional providers (Cursor, Copilot, Gemini CLI, Grok, Kimi, Z.ai, OpenRouter), usage history charts, menu bar mini-graphs.

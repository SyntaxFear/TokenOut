# BurnBar Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A complete, locally installed macOS menu bar app that live-tracks Claude Code, Codex, and Antigravity usage limits, token burn, and cost estimates.

**Architecture:** SwiftPM package with three targets — `BurnBarCore` (models, refresh engine, store; pure logic), `BurnBarProviders` (Claude/Codex/Antigravity, each one folder conforming to `UsageProvider`), `BurnBar` (SwiftUI `MenuBarExtra` app). A bundling script assembles and ad-hoc-signs `BurnBar.app`; a `burnbar-probe` dev CLI captures live API fixtures. UI consumes only the normalized `UsageSnapshot` — providers are plug-ins.

**Tech Stack:** Swift 6 (tools 6.0, swift-testing for tests), SwiftUI `MenuBarExtra(.window)`, `SecItemCopyMatching` (Keychain read), `URLSession` async, `UNUserNotificationCenter`, `SMAppService`, CoreGraphics icon generation, `iconutil`/`codesign` in scripts.

**Working directory: `~/Desktop/BurnBar` — all paths below are relative to it. Commit after every task.**

---

## File map

```
Package.swift
Sources/BurnBarCore/{Models,UsageProvider,RefreshPolicy,UsageStore,Pricing,Format}.swift
Sources/BurnBarProviders/Claude/{ClaudeProvider,ClaudeCredentials,ClaudeUsageAPI,ClaudeTranscripts}.swift
Sources/BurnBarProviders/Codex/{CodexProvider,CodexAuth,CodexUsageAPI}.swift
Sources/BurnBarProviders/Antigravity/AntigravityProvider.swift
Sources/BurnBarProbe/main.swift                     (dev CLI)
Sources/BurnBarApp/{BurnBarApp,AppState,MenuBarLabel,PopoverView,ProviderCard,SettingsView,OnboardingWindow,Notifier}.swift
Tests/BurnBarCoreTests/{FormatTests,PricingTests,WindowTests,StoreTests}.swift
Tests/BurnBarProvidersTests/{ClaudeTranscriptTests,ClaudeUsageDecodingTests,CodexTests}.swift
Tests/BurnBarProvidersTests/Fixtures/*.json|jsonl
Support/Info.plist
scripts/{makeicon.swift,bundle.sh,install-local.sh}
docs/providers/antigravity.md                       (spike output)
```

---

### Task 1: Scaffold

**Files:** Create `Package.swift`, `.gitignore`, empty source files per file map.

- [ ] **Step 1: Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BurnBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BurnBarCore"),
        .target(name: "BurnBarProviders", dependencies: ["BurnBarCore"]),
        .executableTarget(name: "BurnBar", dependencies: ["BurnBarCore", "BurnBarProviders"],
                          path: "Sources/BurnBarApp"),
        .executableTarget(name: "BurnBarProbe", dependencies: ["BurnBarCore", "BurnBarProviders"]),
        .testTarget(name: "BurnBarCoreTests", dependencies: ["BurnBarCore"]),
        .testTarget(name: "BurnBarProvidersTests", dependencies: ["BurnBarProviders"],
                    resources: [.copy("Fixtures")]),
    ]
)
```

- [ ] **Step 2: .gitignore** — `.build/`, `dist/`, `.DS_Store`, `*.icns` artifacts dir
- [ ] **Step 3:** Create all listed swift files with `// BurnBar` placeholder comment so targets compile. Run `swift build` → succeeds. Commit `chore: scaffold SwiftPM package`.

### Task 2: Core models + formatting (TDD)

**Files:** `Sources/BurnBarCore/Models.swift`, `Format.swift`; `Tests/BurnBarCoreTests/{WindowTests,FormatTests}.swift`

- [ ] **Step 1: Failing tests** (swift-testing):

```swift
import Testing, Foundation
@testable import BurnBarCore

@Test func tightestWindowPicksHighestFraction() {
    let a = UsageSnapshot(providerID: .claude, fetchedAt: .now, windows: [
        .init(label: "5-hour", kind: .session, usedFraction: 0.42, resetsAt: nil),
        .init(label: "Weekly", kind: .weekly, usedFraction: 0.81, resetsAt: nil)])
    let b = UsageSnapshot(providerID: .codex, fetchedAt: .now, windows: [
        .init(label: "5-hour", kind: .session, usedFraction: 0.30, resetsAt: nil)])
    let t = UsageMath.tightest(in: [a, b])
    #expect(t?.snapshot.providerID == .claude && t?.window.usedFraction == 0.81)
}
@Test func countdownFormats() {
    #expect(Format.countdown(seconds: 8100) == "2:15")
    #expect(Format.countdown(seconds: 45) == "0:01")
    #expect(Format.tokens(2_340_000) == "2.3M")
    #expect(Format.tokens(950) == "950")
    #expect(Format.tokens(12_400) == "12.4K")
}
```

- [ ] **Step 2:** `swift test` → FAIL (types undefined)
- [ ] **Step 3: Implement Models.swift:**

```swift
import Foundation

public enum ProviderID: String, Codable, CaseIterable, Sendable { case claude, codex, antigravity }

public struct LimitWindow: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case session, weekly, credits }
    public var label: String
    public var kind: Kind
    public var usedFraction: Double     // 0.0–1.0
    public var resetsAt: Date?
    public init(label: String, kind: Kind, usedFraction: Double, resetsAt: Date?) { ... } // memberwise, clamps 0...1
}

public struct TokenTotals: Codable, Sendable, Equatable {
    public var todayTokens: Int, weekTokens: Int
    public var todayCostUSD: Double?, weekCostUSD: Double?
}

public struct DetailLine: Codable, Sendable, Equatable { public var title: String; public var value: String }

public struct UsageSnapshot: Codable, Sendable, Equatable {
    public var providerID: ProviderID
    public var fetchedAt: Date
    public var accountLabel: String?
    public var windows: [LimitWindow]
    public var tokens: TokenTotals?
    public var detail: [DetailLine] = []
}

public enum ProviderStatus: Codable, Sendable, Equatable {
    case ok, stale(since: Date), signedOut(help: String), unsupported(reason: String)
}

public enum UsageMath {
    public static func tightest(in snaps: [UsageSnapshot]) -> (snapshot: UsageSnapshot, window: LimitWindow)? {
        snaps.flatMap { s in s.windows.filter { $0.kind != .credits }.map { (s, $0) } }
             .max { $0.1.usedFraction < $1.1.usedFraction }
    }
}
```

**Format.swift:** `countdown(seconds:)` → "H:MM" ceiling to minute, `tokens(_:)` → 950 / 12.4K / 2.3M, `pct(_:)` → "81%", `usd(_:)` → "$34.20".

- [ ] **Step 4:** `swift test` → PASS. **Step 5:** Commit `feat(core): normalized usage models and formatting`.

### Task 3: Pricing (TDD)

**Files:** `Sources/BurnBarCore/Pricing.swift`; `Tests/BurnBarCoreTests/PricingTests.swift`

- [ ] **Step 1: Test:** cost of 1M input + 100K output on `claude-sonnet-5` == 3.0 + 1.5; cache read priced at 0.1×input; unknown model falls back to sonnet rates and `isEstimated == true`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement `ModelPricing` table — **consult the `claude-api` skill during execution for the current official per-MTok prices** of opus/sonnet/haiku/fable families (input, output, cache write 1.25×, cache read 0.1×); prefix-match model ids (`claude-opus-4` matches `claude-opus-4-8-20260115`). `Pricing.cost(model:usage:) -> (usd: Double, isEstimated: Bool)`.
- [ ] **Step 4:** PASS. **Step 5:** Commit.

### Task 4: Provider protocol + registry

**Files:** `Sources/BurnBarCore/UsageProvider.swift`

- [ ] **Step 1:**

```swift
public protocol UsageProvider: Sendable {
    static var id: ProviderID { get }
    var displayName: String { get }
    func detectInstallation() async -> Bool
    func fetchUsage() async throws -> UsageSnapshot
}
public enum ProviderError: Error, Sendable { case signedOut(help: String), unsupported(reason: String), network(String), decoding(String) }
```

- [ ] **Step 2:** build, commit `feat(core): UsageProvider protocol`.

### Task 5: UsageStore (TDD)

**Files:** `Sources/BurnBarCore/UsageStore.swift`; `Tests/BurnBarCoreTests/StoreTests.swift`

- [ ] **Step 1: Test:** `PersistedState` round-trips snapshots+statuses to a temp file via `save(to:)`/`load(from:)`; corrupted file loads as empty.
- [ ] **Step 3:** `@MainActor @Observable public final class UsageStore` holding `states: [ProviderID: ProviderState]` (`ProviderState { snapshot: UsageSnapshot?; status: ProviderStatus; lastErrorText: String? }`), `apply(result:for:)`, plus nested Codable `PersistedState` with static load/save (JSON in `~/Library/Application Support/BurnBar/state.json`, injectable URL for tests). Persistence pure functions live outside `@MainActor` for testability.
- [ ] **Steps 2/4/5:** FAIL → PASS → commit.

### Task 6: Refresh policy (TDD) + engine

**Files:** `Sources/BurnBarCore/RefreshPolicy.swift`; `Tests/BurnBarCoreTests/WindowTests.swift` (append)

- [ ] **Step 1: Tests:** `RefreshPolicy.interval(maxUtilization: 0.6, consecutiveFailures: 0) == 60`; `(0.2, 0) == 300`; failures double base up to cap 900: `(0.9, 3)` == `min(60*8, 900)` = 480; jitter fn bounds ±10%.
- [ ] **Step 3:** Pure `RefreshPolicy` struct + `RefreshEngine` (in same file): per-provider `Task` loop — fetch → `store.apply` → sleep `policy.interval(...) * jitter`; `refreshAll()` cancels+reruns; wake trigger hooked from app layer. Engine is thin; only policy is unit-tested.
- [ ] **Steps 2/4/5:** FAIL → PASS → commit `feat(core): refresh policy and engine`.

### Task 7: Claude credentials

**Files:** `Sources/BurnBarProviders/Claude/ClaudeCredentials.swift`; test in `ClaudeTranscriptTests.swift` file section

- [ ] **Step 1: Test (file fallback path):** fixture `claude-credentials.json` `{"claudeAiOauth":{"accessToken":"at","refreshToken":"rt","expiresAt":1893456000000,"subscriptionType":"max"}}` parses; expired detection works.
- [ ] **Step 3:**

```swift
public struct ClaudeOAuth: Codable, Sendable {
    public var accessToken: String, refreshToken: String?, expiresAt: Double?, subscriptionType: String?
    public var isExpired: Bool { (expiresAt ?? .infinity) / 1000 < Date.now.timeIntervalSince1970 + 60 }
}
public enum ClaudeCredentials {
    public static func load() -> ClaudeOAuth? { fromKeychain() ?? fromFile() }
    static func fromKeychain() -> ClaudeOAuth? // SecItemCopyMatching generic password, service "Claude Code-credentials", first match, parse JSON {"claudeAiOauth":{...}}
    static func fromFile(_ url: URL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".claude/.credentials.json")) -> ClaudeOAuth?
    public static func refresh(_ c: ClaudeOAuth) async -> ClaudeOAuth? // POST platform.claude.com/v1/oauth/token, grant_type=refresh_token, client_id 9d1c250a-e61b-44d9-88ed-5944d1962f5e; nil on failure; NEVER persisted
}
```

- [ ] **Steps 2/4/5:** FAIL → PASS → commit. Keychain path verified live in Task 15.

### Task 8: Claude transcript parser (TDD)

**Files:** `Sources/BurnBarProviders/Claude/ClaudeTranscripts.swift`; fixture `Fixtures/claude-transcript.jsonl`; `Tests/BurnBarProvidersTests/ClaudeTranscriptTests.swift`

- [ ] **Step 1: Fixture** — 6 lines: user line (no usage), two assistant lines same `message.id` (streamed dup — usage counted once, last wins), assistant other model, malformed line, assistant line yesterday. **Tests:** dedupe by `(message.id ?? uuid)`; per-day aggregation in local tz; totals today vs week; malformed lines skipped; cost computed via Pricing.
- [ ] **Step 3:** Line-streaming parser (`FileHandle.bytes.lines`-equivalent on String for tests; file URLs in prod): decode minimal `struct Line { timestamp: String?; type: String?; message: Msg? }`, `Msg { id: String?; model: String?; usage: Usage? }`, `Usage { input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens: Int? }` with `JSONDecoder` per line; aggregate `DayTotals`. Directory scanner: `~/.claude/projects/**/*.jsonl` mtime within 8 days; per-file cache keyed `(path, mtime)` in an actor.
- [ ] **Steps 2/4/5:** FAIL → PASS → commit `feat(claude): transcript token/cost aggregation`.

### Task 9: Claude usage API + provider

**Files:** `Sources/BurnBarProviders/Claude/{ClaudeUsageAPI,ClaudeProvider}.swift`; fixture `Fixtures/claude-usage.json`; `Tests/BurnBarProvidersTests/ClaudeUsageDecodingTests.swift`

- [ ] **Step 1: Fixture (best-guess shape, refined against live probe in Task 15):**

```json
{"five_hour":{"utilization":42,"resets_at":"2026-07-17T18:00:00Z"},
 "seven_day":{"utilization":81,"resets_at":"2026-07-23T09:00:00Z"},
 "seven_day_opus":{"utilization":12,"resets_at":"2026-07-23T09:00:00Z"}}
```

**Tests:** decodes to 3 windows, labels "5-hour session"/"Weekly (all models)"/"Weekly (Opus)", fractions 0.42/0.81/0.12; unknown keys ignored; missing `resets_at` tolerated.
- [ ] **Step 3:** Tolerant decoder: top-level `[String: WindowJSON]` via `JSONSerialization`→typed map, known-key ordering, utilization accepted as 0–100 or 0–1 (heuristic: >1.5 ⇒ percent). `ClaudeUsageAPI.fetch(token:) async throws -> [LimitWindow]` — GET `https://api.anthropic.com/api/oauth/usage`, headers `Authorization: Bearer`, `anthropic-beta: oauth-2025-04-20`; 401 → `ProviderError.signedOut`.
`ClaudeProvider`: detect = `~/.claude` exists; fetch = load creds (refresh in-memory if expired) → windows + transcript totals → snapshot (`accountLabel` = subscriptionType capitalized).
- [ ] **Steps 2/4/5:** FAIL → PASS → commit `feat(claude): usage API + provider`.

### Task 10: Codex provider

**Files:** `Sources/BurnBarProviders/Codex/{CodexAuth,CodexUsageAPI,CodexProvider}.swift`; fixtures `Fixtures/codex-auth.json`, `Fixtures/codex-usage.json`; `Tests/BurnBarProvidersTests/CodexTests.swift`

- [ ] **Step 1: Fixtures.** auth: `{"tokens":{"access_token":"<jwt>","refresh_token":"rt","account_id":"acc_1"},"last_refresh":"2026-07-16T10:00:00Z"}` (jwt = header.payload.sig with payload `{"exp": 4102444800, "https://api.openai.com/auth": {"chatgpt_plan_type": "pro"}}` base64url). usage (best-guess, refined in Task 15):

```json
{"rate_limits":{"primary":{"used_percent":37.5,"window_minutes":300,"resets_in_seconds":4980},
                "secondary":{"used_percent":62.0,"window_minutes":10080,"resets_in_seconds":300000}},
 "plan_type":"pro"}
```

**Tests:** auth parse + JWT payload plan extraction + exp check; usage → windows ("5-hour session" for ≤360-min window else "Weekly"), resets_at = now + resets_in_seconds; tolerate missing secondary.
- [ ] **Step 3:** `CodexAuth.load()` from `~/.codex/auth.json`; `refresh()` POST `https://auth.openai.com/oauth/token` (client_id `app_EMoamEEZ73f0CkXaXp7hrann`, in-memory only). `CodexUsageAPI.fetch(token:accountID:)` GET `https://chatgpt.com/backend-api/wham/usage`, headers `Authorization: Bearer`, `chatgpt-account-id`. `CodexProvider`: detect `~/.codex/auth.json`; no token-cost stats in phase 1 (windows only + plan detail line).
- [ ] **Steps 2/4/5:** FAIL → PASS → commit `feat(codex): auth + usage provider`.

### Task 11: Probe CLI

**Files:** `Sources/BurnBarProbe/main.swift`

- [ ] **Step 1:** CLI: `burnbar-probe claude|codex|all` → prints HTTP status + raw JSON (tokens redacted) for each provider's usage endpoint using the credential readers. Used in Task 15 to capture real fixtures.
- [ ] **Step 2:** `swift build` → commit `feat: burnbar-probe dev CLI`.

### Task 12: Antigravity spike + provider

**Files:** `docs/providers/antigravity.md`, `Sources/BurnBarProviders/Antigravity/AntigravityProvider.swift`, tests+fixture if parseable format found

- [ ] **Step 1 (spike, timeboxed):** Dispatch Explore subagent over `~/.antigravity` and `~/Library/Application Support/Antigravity`: find conversation/transcript storage, timestamps/turn counts, any quota or OAuth state. Write findings to `docs/providers/antigravity.md`.
- [ ] **Step 2:** Implement to findings, best-effort tiers: (a) quota windows if creds+endpoint accessible → windows; (b) else local activity stats (sessions/turns today+week) as `DetailLine`s with `windows: []`; (c) else `.unsupported("Antigravity data not readable")`. Detect = App Support dir exists. Test whatever parsing exists with a fixture.
- [ ] **Step 3:** Commit `feat(antigravity): best-effort provider per spike findings`.

### Task 13: App target — state, menu bar, popover

**Files:** `Sources/BurnBarApp/{BurnBarApp,AppState,MenuBarLabel,PopoverView,ProviderCard}.swift`

- [ ] **Step 1: AppState** — `@MainActor @Observable` owning `UsageStore`, `RefreshEngine`, enabled-provider prefs (`UserDefaults`), registry `[ClaudeProvider(), CodexProvider(), AntigravityProvider()]`; wake observer (`NSWorkspace.shared.notificationCenter`, `didWakeNotification` → `refreshAll`).
- [ ] **Step 2: BurnBarApp** —

```swift
@main struct BurnBarApp: App {
    @State private var app = AppState()
    var body: some Scene {
        MenuBarExtra { PopoverView().environment(app) } label: { MenuBarLabel(state: app.menuBarMetric) }
            .menuBarExtraStyle(.window)
        Settings { SettingsView().environment(app) }
    }
}
```

- [ ] **Step 3: MenuBarLabel** — drawn template `NSImage` (flame bezier + 14×5pt rounded bar with fill = tightest fraction) + `Text(pct)`; amber/red conveyed by fill + `!` badge (menu bar strips color). `AppState.menuBarMetric` = tightest across enabled providers (fallback "–").
- [ ] **Step 4: PopoverView / ProviderCard** — card per enabled provider: name + status badge, window rows (gradient progress bar — green→amber ≥0.8→red ≥0.95 — %, `TimelineView`-updated "resets in H:MM"), tokens today + est. $ (`~` prefix when `isEstimated`), detail lines, per-status empty states (`signedOut` help text, `stale` timestamp, `unsupported` reason). Footer: Refresh all ⟳ · Settings (SettingsLink) · Quit. Fixed width 340.
- [ ] **Step 5:** `swift build && swift run BurnBar` smoke (menu bar appears) → commit `feat(app): menu bar + popover UI`.

### Task 14: Settings, notifications, onboarding, login item

**Files:** `Sources/BurnBarApp/{SettingsView,Notifier,OnboardingWindow}.swift`

- [ ] **Step 1: SettingsView** — Form: provider toggles; menu bar metric picker (Tightest / specific provider); refresh cadence picker (Fast 30s/Normal 60s/Relaxed 5min); warn thresholds toggle (80/95); Launch at login (`SMAppService.mainApp` register/unregister, reflects `.status`); About row (version).
- [ ] **Step 2: Notifier** — on each store update: for provider+window, if fraction crosses 0.8/0.95 upward and not yet notified for this `resetsAt` cycle → `UNUserNotificationCenter` banner "Claude 5-hour window at 82% — resets in 1:34". Request auth on first enable.
- [ ] **Step 3: OnboardingWindow** — first-launch `NSWindow` (NSHostingController): what BurnBar reads (local files/Keychain, goes nowhere), detected tools with checkmarks, "the Keychain prompt is expected — click Always Allow", Start button. `UserDefaults` flag.
- [ ] **Step 4:** build+run smoke → commit `feat(app): settings, notifications, onboarding`.

### Task 15: Icon, bundle, install, live verify

**Files:** `Support/Info.plist`, `scripts/{makeicon.swift,bundle.sh,install-local.sh}`, `README.md`

- [ ] **Step 1: Info.plist** — `LSUIElement=true`, id `dev.burnbar.mac`, name/display BurnBar, `CFBundleShortVersionString 0.9.0`, `LSMinimumSystemVersion 14.0`, `CFBundleIconFile AppIcon`, `NSHumanReadableCopyright`.
- [ ] **Step 2: makeicon.swift** — AppKit script drawing 1024pt canvas: dark rounded-square bg (#1C1C1E), orange→red vertical gradient flame (two bezier lobes), white 60%-filled rounded bar beneath; render all iconset sizes; `iconutil -c icns` → `Support/AppIcon.icns`.
- [ ] **Step 3: bundle.sh** — `swift build -c release` → assemble `dist/BurnBar.app/Contents/{MacOS/BurnBar,Info.plist,Resources/AppIcon.icns,PkgInfo}` → `codesign --force -s - dist/BurnBar.app`. **install-local.sh** — quit running instance, `ditto` to `/Applications`, `open`.
- [ ] **Step 4: LIVE VERIFY (user present):** run `burnbar-probe all` — user clicks Keychain **Always Allow**; capture real response JSON → sanitize → replace best-guess fixtures; adjust decoders if shapes differ; `swift test` green.
- [ ] **Step 5:** `bundle.sh && install-local.sh`; verify menu bar shows real percentages; screenshot popover; README (what it is, build, install, phase 2 roadmap). Final commit `feat: BurnBar 0.9.0 local release`.

---

## Self-review checklist (run after writing)
- Spec coverage: models✓ providers✓(3) engine✓ store✓ UI✓ settings✓ notifications✓ onboarding✓ icon/bundle/install✓ live-verify✓ — licensing/Sparkle/DMG deliberately phase 2.
- No placeholders; types consistent (`UsageSnapshot`/`LimitWindow`/`ProviderStatus` defined Task 2, used thereafter).
- Every task ends in a commit; tests precede implementations for all pure logic.

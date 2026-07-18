import Testing
import Foundation
@testable import TokenOutCore

@Test func persistedStateRoundTrips() throws {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "tokenout-test-\(UUID().uuidString)/state.json")
    let snapshot = UsageSnapshot(
        providerID: .claude, fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
        accountLabel: "Max",
        windows: [LimitWindow(label: "5-hour session", kind: .session, usedFraction: 0.42,
                              resetsAt: Date(timeIntervalSince1970: 1_800_010_000))],
        tokens: TokenTotals(todayTokens: 1_000, weekTokens: 5_000, todayCostUSD: 1.25))
    let original = PersistedState(states: [.claude: ProviderState(snapshot: snapshot, status: .ok)])

    original.save(to: url)
    let loaded = PersistedState.load(from: url)
    #expect(loaded == original)
    try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
}

@Test func corruptedStateLoadsEmpty() throws {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "tokenout-test-\(UUID().uuidString).json")
    try Data("not json{{{".utf8).write(to: url)
    #expect(PersistedState.load(from: url) == PersistedState())
    try? FileManager.default.removeItem(at: url)
}

@Test @MainActor func storeAppliesResultsAndErrors() {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "tokenout-test-\(UUID().uuidString)/state.json")
    let store = UsageStore(persistenceURL: url)

    let snap = UsageSnapshot(providerID: .codex, fetchedAt: .now, accountLabel: nil,
                             windows: [], tokens: nil)
    store.apply(result: .success(snap), for: .codex)
    #expect(store.states[.codex]?.status == .ok)

    store.apply(result: .failure(ProviderError.signedOut(help: "run codex")), for: .codex)
    #expect(store.states[.codex]?.status == .signedOut(help: "run codex"))
    // Snapshot survives an auth failure so the UI can show last-known data.
    #expect(store.states[.codex]?.snapshot != nil)

    // Soft-fail: transient error over a fresh snapshot keeps the provider
    // healthy — no "stale" badge, no "Some updates failed" noise.
    store.apply(result: .success(snap), for: .codex)
    store.apply(result: .failure(ProviderError.network("timeout")), for: .codex)
    #expect(store.states[.codex]?.status == .ok)
    #expect(store.states[.codex]?.lastErrorText != nil)

    // Rate limiting gets the same soft treatment while data is fresh.
    store.apply(result: .failure(ProviderError.rateLimited(retryAfter: 60)), for: .codex)
    #expect(store.states[.codex]?.status == .ok)

    // But an aged snapshot (>10 min) plus an error is genuinely stale.
    let oldSnap = UsageSnapshot(providerID: .codex,
                                fetchedAt: .now.addingTimeInterval(-11 * 60),
                                accountLabel: nil, windows: [], tokens: nil)
    store.apply(result: .success(oldSnap), for: .codex)
    store.apply(result: .failure(ProviderError.network("timeout")), for: .codex)
    if case .stale = store.states[.codex]?.status {} else { Issue.record("expected stale") }
    try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
}

@Test func refreshPolicyCadence() {
    let p = RefreshPolicy()
    #expect(p.interval(maxUtilization: 0.6, consecutiveFailures: 0) == 60)
    #expect(p.interval(maxUtilization: 0.2, consecutiveFailures: 0) == 300)
    #expect(p.interval(maxUtilization: 0.9, consecutiveFailures: 3) == 480)
    #expect(p.interval(maxUtilization: 0.2, consecutiveFailures: 5) == 900)
    let j = RefreshPolicy.jitter(seed: 12.34)
    #expect(j >= 0.9 && j <= 1.1)
}

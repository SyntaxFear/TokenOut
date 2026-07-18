import Testing
import Foundation
@testable import TokenOutCore

private func tempURL() -> URL {
    FileManager.default.temporaryDirectory
        .appending(path: "tokenout-hist-\(UUID().uuidString)/history.jsonl")
}

@Test func historyRecordsThrottlesAndReloads() throws {
    let url = tempURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let store = HistoryStore(url: url, minInterval: 55)
    let base = Date.now.addingTimeInterval(-600)

    func snap(at time: Date, fraction: Double) -> UsageSnapshot {
        UsageSnapshot(providerID: .claude, fetchedAt: time, accountLabel: nil,
                      windows: [LimitWindow(label: "5-hour session", kind: .session,
                                            usedFraction: fraction, resetsAt: nil)],
                      tokens: TokenTotals(todayTokens: 100, weekTokens: 500, todayCostUSD: 1.5))
    }

    store.record(snapshot: snap(at: base, fraction: 0.40))
    store.record(snapshot: snap(at: base.addingTimeInterval(10), fraction: 0.41))   // throttled
    store.record(snapshot: snap(at: base.addingTimeInterval(120), fraction: 0.45))

    let recorded = store.samples(for: .claude, since: .distantPast)
    #expect(recorded.count == 2)
    #expect(recorded[0].fractions["5-hour session"] == 0.40)
    #expect(recorded[1].fractions["5-hour session"] == 0.45)
    #expect(recorded[0].todayCostUSD == 1.5)

    // A fresh store reloads from disk.
    let reloaded = HistoryStore(url: url)
    #expect(reloaded.samples(for: .claude, since: .distantPast).count == 2)
    #expect(reloaded.samples(for: .codex, since: .distantPast).isEmpty)
}

@Test func burnRateProjectsCapHit() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    // 40% → 55% over 30 minutes = 30%/h; 45% remaining → cap in 1.5h.
    let samples: [(Date, Double)] = [
        (now.addingTimeInterval(-1800), 0.40),
        (now.addingTimeInterval(-900), 0.475),
        (now, 0.55),
    ]
    let projection = BurnRate.projection(samples: samples, now: now)
    #expect(projection != nil)
    #expect(abs((projection?.perHour ?? 0) - 0.30) < 0.001)
    let expected = now.addingTimeInterval(1.5 * 3600)
    #expect(abs(projection!.hitsCapAt.timeIntervalSince(expected)) < 60)
}

@Test func burnRateNilWhenFlatOrSparse() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(BurnRate.projection(samples: [(now, 0.5)], now: now) == nil)
    let flat: [(Date, Double)] = [(now.addingTimeInterval(-1800), 0.5), (now, 0.5)]
    #expect(BurnRate.projection(samples: flat, now: now) == nil)
    let falling: [(Date, Double)] = [(now.addingTimeInterval(-1800), 0.6), (now, 0.4)]
    #expect(BurnRate.projection(samples: falling, now: now) == nil)
    let tooClose: [(Date, Double)] = [(now.addingTimeInterval(-60), 0.4), (now, 0.6)]
    #expect(BurnRate.projection(samples: tooClose, now: now) == nil)
}

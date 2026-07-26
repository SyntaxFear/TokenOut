import Testing
import Foundation
@testable import TokenOutCore

@Test func tightestWindowPicksHighestFraction() {
    let a = UsageSnapshot(providerID: .claude, fetchedAt: .now, accountLabel: nil, windows: [
        LimitWindow(label: "5-hour", kind: .session, usedFraction: 0.42, resetsAt: nil),
        LimitWindow(label: "Weekly", kind: .weekly, usedFraction: 0.81, resetsAt: nil),
    ], tokens: nil)
    let b = UsageSnapshot(providerID: .codex, fetchedAt: .now, accountLabel: nil, windows: [
        LimitWindow(label: "5-hour", kind: .session, usedFraction: 0.30, resetsAt: nil),
    ], tokens: nil)
    let t = UsageMath.tightest(in: [a, b])
    #expect(t?.snapshot.providerID == .claude)
    #expect(t?.window.usedFraction == 0.81)
}

@Test func tightestIgnoresCreditsAndHandlesEmpty() {
    let credits = UsageSnapshot(providerID: .codex, fetchedAt: .now, accountLabel: nil, windows: [
        LimitWindow(label: "Credits", kind: .credits, usedFraction: 0.99, resetsAt: nil),
    ], tokens: nil)
    #expect(UsageMath.tightest(in: [credits]) == nil)
    #expect(UsageMath.tightest(in: []) == nil)
}

@Test func compactWindowsKeepsSessionAndTightestWeekly() {
    let snapshot = UsageSnapshot(providerID: .claude, fetchedAt: .now, accountLabel: nil, windows: [
        LimitWindow(label: "Weekly (Sonnet)", kind: .weekly, usedFraction: 0.44, resetsAt: nil),
        LimitWindow(label: "5-hour", kind: .session, usedFraction: 0.31, resetsAt: nil),
        LimitWindow(label: "Weekly (all models)", kind: .weekly, usedFraction: 0.68, resetsAt: nil),
        LimitWindow(label: "Credits", kind: .credits, usedFraction: 0.99, resetsAt: nil),
    ], tokens: nil)

    let windows = UsageMath.compactWindows(in: snapshot)
    #expect(windows.map(\.label) == ["5-hour", "Weekly (all models)"])
}

@Test func compactWindowsFallsBackWithoutStandardHorizons() {
    let snapshot = UsageSnapshot(providerID: .codex, fetchedAt: .now, accountLabel: nil, windows: [
        LimitWindow(label: "Credits", kind: .credits, usedFraction: 0.80, resetsAt: nil),
    ], tokens: nil)
    #expect(UsageMath.compactWindows(in: snapshot).isEmpty)
}

@Test func usedFractionClamps() {
    #expect(LimitWindow(label: "x", kind: .session, usedFraction: 1.7, resetsAt: nil).usedFraction == 1.0)
    #expect(LimitWindow(label: "x", kind: .session, usedFraction: -0.2, resetsAt: nil).usedFraction == 0.0)
}

@Test func countdownFormats() {
    #expect(Format.countdown(seconds: 8100) == "2:15")
    #expect(Format.countdown(seconds: 45) == "0:01")
    #expect(Format.countdown(seconds: 0) == "0:00")
    #expect(Format.countdown(seconds: -30) == "0:00")
    #expect(Format.countdown(seconds: 90000) == "25:00")
}

@Test func tokenFormats() {
    #expect(Format.tokens(950) == "950")
    #expect(Format.tokens(12_400) == "12.4K")
    #expect(Format.tokens(2_340_000) == "2.3M")
    #expect(Format.tokens(0) == "0")
    #expect(Format.tokens(1_000_000_000) == "1.0B")
}

@Test func percentAndUSDFormats() {
    #expect(Format.pct(0.814) == "81%")
    #expect(Format.pct(1.0) == "100%")
    #expect(Format.usd(34.204) == "$34.20")
    #expect(Format.usd(0) == "$0.00")
}

@Test func humanCountdownFormats() {
    #expect(Format.humanCountdown(seconds: 30) == "under 1 m")
    #expect(Format.humanCountdown(seconds: 50 * 60) == "50 m")
    #expect(Format.humanCountdown(seconds: 6600) == "1 h 50 m")
    #expect(Format.humanCountdown(seconds: 2 * 3600) == "2 h")
    #expect(Format.humanCountdown(seconds: 3 * 86_400 + 9 * 3600) == "3 d 9 h")
    #expect(Format.humanCountdown(seconds: 7 * 86_400) == "7 d")
}

@Test func paceDeltaComputes() {
    let now = Date.now
    // 3 h into a 5 h window (60% elapsed), 40% used → 20% in reserve.
    let reserve = LimitWindow(label: "5-hour", kind: .session, usedFraction: 0.4,
                              resetsAt: now.addingTimeInterval(2 * 3600), duration: 5 * 3600)
    #expect(abs((reserve.paceDelta(now: now) ?? 0) - (-0.2)) < 0.001)
    #expect(abs((reserve.elapsedFraction(now: now) ?? 0) - 0.6) < 0.001)

    // 30% of the week elapsed, 60% used → 30% deficit.
    let deficit = LimitWindow(label: "Weekly", kind: .weekly, usedFraction: 0.6,
                              resetsAt: now.addingTimeInterval(4.9 * 86_400), duration: 7 * 86_400)
    #expect(abs((deficit.paceDelta(now: now) ?? 0) - 0.3) < 0.001)

    // No duration or no reset date → no pace signal, never a bogus one.
    let noDuration = LimitWindow(label: "x", kind: .session, usedFraction: 0.5,
                                 resetsAt: now.addingTimeInterval(3600))
    #expect(noDuration.paceDelta(now: now) == nil)
    let noReset = LimitWindow(label: "x", kind: .session, usedFraction: 0.5,
                              resetsAt: nil, duration: 5 * 3600)
    #expect(noReset.paceDelta(now: now) == nil)

    // Elapsed clamps: a reset date further out than the duration reads as 0 elapsed.
    let clamped = LimitWindow(label: "x", kind: .session, usedFraction: 0.1,
                              resetsAt: now.addingTimeInterval(9 * 3600), duration: 5 * 3600)
    #expect(clamped.elapsedFraction(now: now) == 0)
}

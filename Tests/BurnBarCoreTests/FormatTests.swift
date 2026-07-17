import Testing
import Foundation
@testable import BurnBarCore

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

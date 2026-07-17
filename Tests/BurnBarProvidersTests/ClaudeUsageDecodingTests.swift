import Testing
import Foundation
@testable import BurnBarProviders
import BurnBarCore

@Test func usageResponseDecodesLimitsArray() throws {
    // Fixture is a sanitized capture of the real endpoint (2026-07-17).
    let url = Bundle.module.url(forResource: "claude-usage", withExtension: "json",
                                subdirectory: "Fixtures")!
    let windows = ClaudeUsageAPI.decodeWindows(from: try Data(contentsOf: url))

    #expect(windows.count == 3)
    let session = try #require(windows.first { $0.kind == .session })
    #expect(session.label == "5-hour session")
    #expect(abs(session.usedFraction - 0.43) < 0.0001)
    #expect(session.resetsAt != nil)  // 6-digit fractional seconds must parse

    let scoped = try #require(windows.first { $0.label == "Weekly (Fable)" })
    #expect(abs(scoped.usedFraction - 0.56) < 0.0001)

    // The scoped Fable window is the tightest — exactly what the menu bar should show.
    let snap = UsageSnapshot(providerID: .claude, fetchedAt: .now, accountLabel: nil,
                             windows: windows, tokens: nil)
    #expect(UsageMath.tightest(in: [snap])?.window.label == "Weekly (Fable)")
}

@Test func usageResponseFallsBackToFlatKeys() {
    let json = """
    {"five_hour": {"utilization": 42, "resets_at": "2026-07-17T18:00:00Z"},
     "seven_day": {"utilization": 81, "resets_at": "2026-07-23T09:00:00Z"}}
    """
    let windows = ClaudeUsageAPI.decodeWindows(from: Data(json.utf8))
    #expect(windows.count == 2)
    #expect(windows[0].label == "5-hour session")
    #expect(abs(windows[1].usedFraction - 0.81) < 0.0001)
}

@Test func usageDecodingToleratesFractionsAndMissingResets() {
    let json = #"{"five_hour": {"utilization": 0.37}}"#
    let windows = ClaudeUsageAPI.decodeWindows(from: Data(json.utf8))
    #expect(windows.count == 1)
    #expect(abs(windows[0].usedFraction - 0.37) < 0.0001)
    #expect(windows[0].resetsAt == nil)
}

@Test func garbageDecodesToEmpty() {
    #expect(ClaudeUsageAPI.decodeWindows(from: Data("[1,2,3]".utf8)).isEmpty)
    #expect(ClaudeUsageAPI.decodeWindows(from: Data("garbage".utf8)).isEmpty)
}

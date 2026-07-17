import Testing
import Foundation
@testable import BurnBarProviders
import BurnBarCore

@Test func usageResponseDecodesToWindows() throws {
    let url = Bundle.module.url(forResource: "claude-usage", withExtension: "json",
                                subdirectory: "Fixtures")!
    let windows = ClaudeUsageAPI.decodeWindows(from: try Data(contentsOf: url))

    #expect(windows.count == 3)  // unknown key ignored
    let session = try #require(windows.first { $0.kind == .session })
    #expect(session.label == "5-hour session")
    #expect(abs(session.usedFraction - 0.42) < 0.0001)
    #expect(session.resetsAt != nil)

    let weekly = try #require(windows.first { $0.label == "Weekly (all models)" })
    #expect(abs(weekly.usedFraction - 0.81) < 0.0001)
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

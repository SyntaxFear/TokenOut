import Testing
import Foundation
@testable import BurnBarProviders
import BurnBarCore

private func fixtureURL(_ name: String) -> URL {
    Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
}

@Test func transcriptParsingDedupesAndAggregates() throws {
    let text = try String(contentsOf: fixtureURL("claude-transcript.jsonl"), encoding: .utf8)
    let entries = ClaudeTranscriptParser.parse(text)

    // 5 assistant lines; msg_dup counted once (last wins), msg_nousage skipped, bad line skipped.
    #expect(entries.count == 3)

    let dup = entries.first { $0.messageID == "msg_dup" }
    #expect(dup?.usage.output == 40)
    #expect(dup?.usage.cacheWrite1h == 100)
    #expect(dup?.usage.cacheWrite == 0)

    // Aggregate "today" (2026-07-17) vs the day before, pinned to UTC for determinism.
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let ref = ISO8601DateFormatter().date(from: "2026-07-17T12:00:00Z")!
    let today = ClaudeTranscriptParser.total(entries: entries, in: cal.startOfDay(for: ref)...ref)
    // msg_dup(10+100+50+40=200) + msg_2(1000+2000+300=3300); msg_3 was yesterday.
    #expect(today.tokens.total == 3500)
    #expect(today.costUSD > 0)
}

@Test func credentialsParseFromFileFormat() throws {
    let json = """
    {"claudeAiOauth":{"accessToken":"at-123","refreshToken":"rt-456","expiresAt":1893456000000,"scopes":["user:inference"],"subscriptionType":"max"}}
    """
    let creds = try #require(ClaudeCredentials.parse(Data(json.utf8)))
    #expect(creds.accessToken == "at-123")
    #expect(creds.refreshToken == "rt-456")
    #expect(creds.subscriptionType == "max")
    #expect(creds.isExpired == false)  // 2030 epoch ms

    let expired = ClaudeOAuth(accessToken: "x", refreshToken: nil,
                              expiresAt: 1_600_000_000_000, subscriptionType: nil)
    #expect(expired.isExpired == true)
}

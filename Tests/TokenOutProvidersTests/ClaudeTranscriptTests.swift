import Testing
import Foundation
@testable import TokenOutProviders
import TokenOutCore

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
    #expect(creds.scopes == ["user:inference"])
    #expect(creds.isExpired == false)  // 2030 epoch ms

    let expired = ClaudeOAuth(accessToken: "x", refreshToken: nil,
                              expiresAt: 1_600_000_000_000, subscriptionType: nil)
    #expect(expired.isExpired == true)
}

@Test func credentialsRejectClaudeCodesClearedDeadTokenRecord() {
    let json = """
    {"claudeAiOauth":{"accessToken":"","refreshToken":"","expiresAt":0,"scopes":["user:inference"],"subscriptionType":"max"}}
    """
    #expect(ClaudeCredentials.parse(Data(json.utf8)) == nil)
}

@Test func refreshRequestMatchesClaudeCodesFirstPartyScopeContract() throws {
    let credentials = ClaudeOAuth(
        accessToken: "old-access", refreshToken: "old-refresh", expiresAt: 0,
        subscriptionType: "max", scopes: ["user:file_upload", "user:inference"])
    let body = try #require(ClaudeCredentials.refreshRequestBody(
        credentials: credentials, refreshToken: "old-refresh"))
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])

    #expect(json["grant_type"] == "refresh_token")
    #expect(json["client_id"] == "9d1c250a-e61b-44d9-88ed-5944d1962f5e")
    #expect(json["refresh_token"] == "old-refresh")
    let scopes = Set(try #require(json["scope"]).split(separator: " ").map(String.init))
    #expect(scopes == Set([
        "user:profile", "user:inference", "user:sessions:claude_code",
        "user:mcp_servers", "user:file_upload",
    ]))
}

@Test func rotatedCredentialPersistencePreservesUnrelatedClaudeState() throws {
    let original = Data("""
    {"organizationUuid":"org-1","mcpOAuth":{"server":{"token":"keep"}},"claudeAiOauth":{"accessToken":"old","refreshToken":"old-r","expiresAt":1,"scopes":["user:inference"],"subscriptionType":"max","rateLimitTier":"tier"}}
    """.utf8)
    let refreshed = ClaudeOAuth(
        accessToken: "new", refreshToken: "new-r", expiresAt: 2,
        subscriptionType: "max", scopes: ["user:profile", "user:inference"],
        rateLimitTier: "tier")
    let updated = try #require(ClaudeCredentials.updatedCredentialData(original, with: refreshed))
    let root = try #require(JSONSerialization.jsonObject(with: updated) as? [String: Any])
    let oauth = try #require(root["claudeAiOauth"] as? [String: Any])
    let mcp = try #require(root["mcpOAuth"] as? [String: Any])

    #expect(root["organizationUuid"] as? String == "org-1")
    #expect((mcp["server"] as? [String: String])?["token"] == "keep")
    #expect(oauth["accessToken"] as? String == "new")
    #expect(oauth["refreshToken"] as? String == "new-r")
    #expect((oauth["expiresAt"] as? NSNumber)?.doubleValue == 2)
}

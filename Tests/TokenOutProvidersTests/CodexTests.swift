import Testing
import Foundation
@testable import TokenOutProviders
import TokenOutCore

private func b64url(_ json: String) -> String {
    Data(json.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

@Test func codexAuthParsesJWTClaims() throws {
    let payload = """
    {"exp": 4102444800, "https://api.openai.com/auth": {"chatgpt_plan_type": "pro", "chatgpt_account_id": "acc_jwt"}}
    """
    let jwt = "\(b64url("{\"alg\":\"RS256\"}")).\(b64url(payload)).sig"
    let authJSON = """
    {"tokens": {"access_token": "\(jwt)", "refresh_token": "rt-1", "account_id": "acc_file", "id_token": "x"}}
    """
    let auth = try #require(CodexAuthReader.parse(Data(authJSON.utf8)))
    #expect(auth.planType == "pro")
    #expect(auth.accountID == "acc_file")  // explicit file value wins over JWT claim
    #expect(auth.isExpired == false)       // exp year 2100
    #expect(auth.refreshToken == "rt-1")
}

@Test func codexAuthExpiredJWTDetected() throws {
    let jwt = "\(b64url("{}")).\(b64url(#"{"exp": 1600000000}"#)).sig"
    let auth = try #require(CodexAuthReader.parse(
        Data(#"{"tokens": {"access_token": "\#(jwt)"}}"#.utf8)))
    #expect(auth.isExpired == true)
}

@Test func codexUsageDecodesLiveShape() throws {
    // Fixture is a sanitized capture of the real endpoint (2026-07-17).
    let url = Bundle.module.url(forResource: "codex-usage", withExtension: "json",
                                subdirectory: "Fixtures")!
    let data = try Data(contentsOf: url)
    let windows = CodexUsageAPI.decodeWindows(from: data)

    #expect(windows.count == 1)  // secondary_window is null
    #expect(windows[0].label == "Monthly")  // 2,592,000 s = 30-day window
    #expect(windows[0].kind == .weekly)
    #expect(windows[0].usedFraction == 1.0)
    #expect(windows[0].resetsAt == Date(timeIntervalSince1970: 1_784_829_645))
    #expect(CodexUsageAPI.decodePlan(from: data) == "free")
}

@Test func codexUsageDecodesLegacyGuessShape() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let json = """
    {"rate_limits": {
       "primary": {"used_percent": 37.5, "window_minutes": 300, "resets_in_seconds": 4980},
       "secondary": {"used_percent": 62.0, "window_minutes": 10080, "resets_in_seconds": 300000}},
     "plan_type": "pro"}
    """
    let windows = CodexUsageAPI.decodeWindows(from: Data(json.utf8), now: now)
    #expect(windows.count == 2)
    #expect(windows[0].label == "5-hour session")
    #expect(windows[0].kind == .session)
    #expect(abs(windows[0].usedFraction - 0.375) < 0.0001)
    #expect(windows[0].resetsAt == now.addingTimeInterval(4980))
    #expect(windows[1].label == "Weekly")
    #expect(CodexUsageAPI.decodePlan(from: Data(json.utf8)) == "pro")
}

@Test func codexUsageToleratesMissingSecondary() {
    let json = #"{"rate_limits": {"primary": {"used_percent": 10, "window_minutes": 300}}}"#
    let windows = CodexUsageAPI.decodeWindows(from: Data(json.utf8))
    #expect(windows.count == 1)
    #expect(windows[0].resetsAt == nil)
    #expect(CodexUsageAPI.decodeWindows(from: Data("junk".utf8)).isEmpty)
}

import Testing
import Foundation
@testable import BurnBarProviders
import BurnBarCore

@Test func projectLabelStripsKnownPrefixes() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
        .replacingOccurrences(of: "/", with: "-")
    #expect(ClaudeTranscriptParser.projectLabel(fromEncodedDir: "\(home)-Desktop-FreeWorker")
            == "FreeWorker")
    #expect(ClaudeTranscriptParser.projectLabel(fromEncodedDir: "\(home)-Desktop-booking-website")
            == "booking-website")  // hyphenated names survive
    #expect(ClaudeTranscriptParser.projectLabel(fromEncodedDir: "\(home)-wandero-frontend")
            == "wandero-frontend")
    #expect(ClaudeTranscriptParser.projectLabel(fromEncodedDir: "-Volumes-Work-thing")
            == "Volumes-Work-thing")  // unknown roots stay verbatim minus leading dash
}

@Test func modelFamilyPrettyPrints() {
    #expect(ClaudeTranscriptParser.modelFamily("claude-opus-4-8") == "Opus 4.8")
    #expect(ClaudeTranscriptParser.modelFamily("claude-opus-4-5-20251101") == "Opus 4.5")
    #expect(ClaudeTranscriptParser.modelFamily("claude-fable-5") == "Fable 5")
    #expect(ClaudeTranscriptParser.modelFamily("claude-sonnet-5") == "Sonnet 5")
}

@Test func groupTotalsSortByCost() {
    func entry(_ model: String, _ project: String, output: Int, at ts: Date) -> TranscriptEntry {
        TranscriptEntry(messageID: UUID().uuidString, model: model, timestamp: ts,
                        usage: TokenUsage(output: output), project: project)
    }
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let entries = [
        entry("claude-opus-4-8", "BurnBar", output: 1_000_000, at: now),        // $25
        entry("claude-sonnet-5", "BurnBar", output: 100_000, at: now),          // $1.50
        entry("claude-opus-4-8", "FreeWorker", output: 200_000, at: now),       // $5
        entry("claude-opus-4-8", "old", output: 500_000, at: now.addingTimeInterval(-86_400 * 2)),
    ]
    let range = now.addingTimeInterval(-3600)...now

    let byModel = ClaudeTranscriptParser.totals(entries: entries, in: range) {
        ClaudeTranscriptParser.modelFamily($0.model)
    }
    #expect(byModel.map(\.name) == ["Opus 4.8", "Sonnet 5"])
    #expect(abs(byModel[0].costUSD - 30.0) < 0.001)

    let byProject = ClaudeTranscriptParser.totals(entries: entries, in: range) { $0.project }
    #expect(byProject.map(\.name) == ["BurnBar", "FreeWorker"])
}

@Test func codexCreditsDecode() {
    #expect(CodexUsageAPI.decodeCredits(
        from: Data(#"{"credits": {"unlimited": true}}"#.utf8)) == "Unlimited")
    #expect(CodexUsageAPI.decodeCredits(
        from: Data(#"{"credits": {"balance": 12.5, "has_credits": true}}"#.utf8)) == "$12.50")
    #expect(CodexUsageAPI.decodeCredits(
        from: Data(#"{"credits": {"has_credits": false, "balance": null}}"#.utf8)) == nil)
    #expect(CodexUsageAPI.decodeCredits(from: Data("{}".utf8)) == nil)
}

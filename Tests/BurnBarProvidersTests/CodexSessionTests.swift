import Testing
import Foundation
@testable import BurnBarProviders
import BurnBarCore

@Test func codexRolloutParsesLastCumulativeUsage() {
    let text = """
    {"timestamp":"t","type":"turn_context","payload":{"model":"gpt-5.6-sol"}}
    {"timestamp":"t","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":10,"total_tokens":110}}}}
    not json {{{
    {"timestamp":"t","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":23258,"cached_input_tokens":4000,"output_tokens":289,"total_tokens":23547}}}}
    """
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let stat = CodexSessionScanner.parseRollout(text: text, date: date)
    #expect(stat?.model == "gpt-5.6-sol")
    #expect(stat?.input == 23258)          // last cumulative wins
    #expect(stat?.cachedInput == 4000)
    #expect(stat?.totalTokens == 23547)
    #expect(CodexSessionScanner.parseRollout(text: "{}", date: date) == nil)

    let cost = CodexSessionScanner.cost(of: stat!)
    let expected = (Double(23258 - 4000) * 1.25 + 4000 * 0.125 + 289 * 10.0) / 1_000_000
    #expect(abs(cost - expected) < 0.000001)
}

@Test func codexRolloutFilenameDate() {
    let date = CodexSessionScanner.dateFromFilename(
        "rollout-2026-07-16T23-08-39-019f6c54.jsonl")
    #expect(date != nil)
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date!)
    #expect(parts.year == 2026 && parts.month == 7 && parts.day == 16)
    #expect(CodexSessionScanner.dateFromFilename("other.jsonl") == nil)
}

@Test func dayStatAggregatesByCalendarDay() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let now = ISO8601DateFormatter().date(from: "2026-07-17T12:00:00Z")!
    let points: [(Date, Int, Double, String)] = [
        (ISO8601DateFormatter().date(from: "2026-07-17T09:00:00Z")!, 100, 1.0, "Fable 5"),
        (ISO8601DateFormatter().date(from: "2026-07-17T11:00:00Z")!, 50, 0.5, "Opus 4.8"),
        (ISO8601DateFormatter().date(from: "2026-07-16T09:00:00Z")!, 30, 0.3, "Fable 5"),
        (ISO8601DateFormatter().date(from: "2026-01-01T09:00:00Z")!, 999, 9.9, "x"),  // outside range
    ]
    let daily = DayStat.aggregate(points: points, days: 30, calendar: cal, now: now)
    #expect(daily.count == 2)
    #expect(daily[0].tokens == 30)       // oldest first
    #expect(daily[1].tokens == 150)
    #expect(abs(daily[1].costUSD - 1.5) < 0.0001)
    #expect(daily[1].topModelText == "Fable 5 (67%)")
}

import Foundation

/// Raw token counts for one request or an aggregate.
public struct TokenUsage: Codable, Sendable, Equatable {
    public var input: Int
    public var output: Int
    /// 5-minute-TTL cache writes (1.25x input rate).
    public var cacheWrite: Int
    /// 1-hour-TTL cache writes (2x input rate) — Claude Code predominantly uses these.
    public var cacheWrite1h: Int
    public var cacheRead: Int

    public init(input: Int = 0, output: Int = 0, cacheWrite: Int = 0,
                cacheWrite1h: Int = 0, cacheRead: Int = 0) {
        self.input = input
        self.output = output
        self.cacheWrite = cacheWrite
        self.cacheWrite1h = cacheWrite1h
        self.cacheRead = cacheRead
    }

    public var total: Int { input + output + cacheWrite + cacheWrite1h + cacheRead }

    public static func + (a: TokenUsage, b: TokenUsage) -> TokenUsage {
        TokenUsage(input: a.input + b.input, output: a.output + b.output,
                   cacheWrite: a.cacheWrite + b.cacheWrite,
                   cacheWrite1h: a.cacheWrite1h + b.cacheWrite1h,
                   cacheRead: a.cacheRead + b.cacheRead)
    }
}

/// API-equivalent dollar value of token usage. Rates are USD per million tokens
/// (official list prices as of 2026-06; cache write 1.25x input, cache read 0.1x input).
public enum Pricing {
    struct Rate { let input: Double; let output: Double }

    /// Ordered longest-prefix-first so dated ids ("claude-opus-4-5-20251101") match their family.
    static let rates: [(prefix: String, rate: Rate)] = [
        ("claude-fable-5", Rate(input: 10, output: 50)),
        ("claude-mythos-5", Rate(input: 10, output: 50)),
        ("claude-opus-4-8", Rate(input: 5, output: 25)),
        ("claude-opus-4-7", Rate(input: 5, output: 25)),
        ("claude-opus-4-6", Rate(input: 5, output: 25)),
        ("claude-opus-4-5", Rate(input: 5, output: 25)),
        ("claude-opus-4-1", Rate(input: 15, output: 75)),
        ("claude-opus-4", Rate(input: 15, output: 75)),
        ("claude-3-opus", Rate(input: 15, output: 75)),
        ("claude-sonnet-5", Rate(input: 3, output: 15)),
        ("claude-sonnet-4", Rate(input: 3, output: 15)),
        ("claude-3-7-sonnet", Rate(input: 3, output: 15)),
        ("claude-3-5-sonnet", Rate(input: 3, output: 15)),
        ("claude-haiku-4-5", Rate(input: 1, output: 5)),
        ("claude-3-5-haiku", Rate(input: 0.8, output: 4)),
        ("claude-3-haiku", Rate(input: 0.25, output: 1.25)),
    ]

    static let fallback = Rate(input: 3, output: 15)

    public static func cost(model: String, usage: TokenUsage) -> (usd: Double, isEstimated: Bool) {
        if model.hasPrefix("<") { return (0, false) }  // "<synthetic>" placeholder entries
        let matched = rates.first { model.hasPrefix($0.prefix) }?.rate
        var rate = matched ?? fallback
        // Sonnet 5 introductory pricing ($2/$10) runs through 2026-08-31.
        if model.hasPrefix("claude-sonnet-5"),
           Date.now.timeIntervalSince1970 < 1_787_875_200 {
            rate = Rate(input: 2, output: 10)
        }
        let usd = (Double(usage.input) * rate.input
                 + Double(usage.output) * rate.output
                 + Double(usage.cacheWrite) * rate.input * 1.25
                 + Double(usage.cacheWrite1h) * rate.input * 2.0
                 + Double(usage.cacheRead) * rate.input * 0.1) / 1_000_000
        return (usd, matched == nil)
    }
}

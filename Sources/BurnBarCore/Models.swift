import Foundation

/// Identifies a supported AI tool. Adding a provider starts here.
public enum ProviderID: String, Codable, CaseIterable, Sendable, Identifiable {
    case claude, codex, antigravity
    public var id: String { rawValue }
}

/// One rate-limit window (5-hour session, weekly cap, credit pool…), normalized to 0–1.
public struct LimitWindow: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case session, weekly, credits }

    public var label: String
    public var kind: Kind
    public var usedFraction: Double
    public var resetsAt: Date?

    public init(label: String, kind: Kind, usedFraction: Double, resetsAt: Date?) {
        self.label = label
        self.kind = kind
        self.usedFraction = min(1.0, max(0.0, usedFraction))
        self.resetsAt = resetsAt
    }
}

/// Aggregated local token stats for a provider.
public struct TokenTotals: Codable, Sendable, Equatable {
    public var todayTokens: Int
    public var weekTokens: Int
    public var todayCostUSD: Double?
    public var weekCostUSD: Double?
    public var costIsEstimated: Bool

    public init(todayTokens: Int, weekTokens: Int, todayCostUSD: Double? = nil,
                weekCostUSD: Double? = nil, costIsEstimated: Bool = false) {
        self.todayTokens = todayTokens
        self.weekTokens = weekTokens
        self.todayCostUSD = todayCostUSD
        self.weekCostUSD = weekCostUSD
        self.costIsEstimated = costIsEstimated
    }
}

/// Provider-specific extra rows the UI renders generically.
public struct DetailLine: Codable, Sendable, Equatable {
    public var title: String
    public var value: String
    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }
}

/// A grouped mini-table ("By model", "By project") rendered generically with tiny bars.
public struct Breakdown: Codable, Sendable, Equatable {
    public struct Row: Codable, Sendable, Equatable {
        public var name: String
        public var valueText: String
        /// Share of the group's total, 0–1, for bar scaling.
        public var fraction: Double
        public init(name: String, valueText: String, fraction: Double) {
            self.name = name
            self.valueText = valueText
            self.fraction = min(1, max(0, fraction))
        }
    }
    public var title: String
    public var rows: [Row]
    public init(title: String, rows: [Row]) {
        self.title = title
        self.rows = rows
    }
}

/// The normalized result every provider produces; the UI consumes nothing else.
public struct UsageSnapshot: Codable, Sendable, Equatable {
    public var providerID: ProviderID
    public var fetchedAt: Date
    public var accountLabel: String?
    public var windows: [LimitWindow]
    public var tokens: TokenTotals?
    public var detail: [DetailLine]
    public var breakdowns: [Breakdown]
    /// Day-by-day usage, oldest first, for the daily chart (up to ~90 days).
    public var daily: [DayStat]

    public init(providerID: ProviderID, fetchedAt: Date, accountLabel: String?,
                windows: [LimitWindow], tokens: TokenTotals?, detail: [DetailLine] = [],
                breakdowns: [Breakdown] = [], daily: [DayStat] = []) {
        self.providerID = providerID
        self.fetchedAt = fetchedAt
        self.accountLabel = accountLabel
        self.windows = windows
        self.tokens = tokens
        self.detail = detail
        self.breakdowns = breakdowns
        self.daily = daily
    }

    enum CodingKeys: String, CodingKey {
        case providerID, fetchedAt, accountLabel, windows, tokens, detail, breakdowns, daily
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        providerID = try c.decode(ProviderID.self, forKey: .providerID)
        fetchedAt = try c.decode(Date.self, forKey: .fetchedAt)
        accountLabel = try c.decodeIfPresent(String.self, forKey: .accountLabel)
        windows = try c.decode([LimitWindow].self, forKey: .windows)
        tokens = try c.decodeIfPresent(TokenTotals.self, forKey: .tokens)
        detail = try c.decodeIfPresent([DetailLine].self, forKey: .detail) ?? []
        breakdowns = try c.decodeIfPresent([Breakdown].self, forKey: .breakdowns) ?? []
        daily = try c.decodeIfPresent([DayStat].self, forKey: .daily) ?? []
    }
}

/// One calendar day's usage.
public struct DayStat: Codable, Sendable, Equatable {
    public var day: Date
    public var tokens: Int
    public var costUSD: Double
    public var costIsEstimated: Bool

    public init(day: Date, tokens: Int, costUSD: Double, costIsEstimated: Bool = false) {
        self.day = day
        self.tokens = tokens
        self.costUSD = costUSD
        self.costIsEstimated = costIsEstimated
    }

    /// Group (date, tokens, cost) points into per-day stats, oldest first, within `days`.
    public static func aggregate(points: [(Date, Int, Double)], days: Int,
                                 calendar: Calendar = .current, now: Date = .now,
                                 estimated: Bool = false) -> [DayStat] {
        let cutoff = calendar.startOfDay(for: now.addingTimeInterval(-Double(days - 1) * 86400))
        var byDay: [Date: DayStat] = [:]
        for (ts, tokens, cost) in points where ts >= cutoff {
            let day = calendar.startOfDay(for: ts)
            var stat = byDay[day] ?? DayStat(day: day, tokens: 0, costUSD: 0, costIsEstimated: estimated)
            stat.tokens += tokens
            stat.costUSD += cost
            byDay[day] = stat
        }
        return byDay.values.sorted { $0.day < $1.day }
    }
}

/// Health of a provider's last fetch; errors degrade a card, never the app.
public enum ProviderStatus: Codable, Sendable, Equatable {
    case ok
    case stale(since: Date)
    case signedOut(help: String)
    case unsupported(reason: String)
}

public enum UsageMath {
    /// The window closest to its cap across all snapshots — the number that decides
    /// whether the user can keep working. Credit pools don't compete.
    public static func tightest(in snaps: [UsageSnapshot]) -> (snapshot: UsageSnapshot, window: LimitWindow)? {
        snaps
            .flatMap { snap in snap.windows.filter { $0.kind != .credits }.map { (snapshot: snap, window: $0) } }
            .max { $0.window.usedFraction < $1.window.usedFraction }
    }
}

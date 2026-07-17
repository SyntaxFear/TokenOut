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

/// The normalized result every provider produces; the UI consumes nothing else.
public struct UsageSnapshot: Codable, Sendable, Equatable {
    public var providerID: ProviderID
    public var fetchedAt: Date
    public var accountLabel: String?
    public var windows: [LimitWindow]
    public var tokens: TokenTotals?
    public var detail: [DetailLine]

    public init(providerID: ProviderID, fetchedAt: Date, accountLabel: String?,
                windows: [LimitWindow], tokens: TokenTotals?, detail: [DetailLine] = []) {
        self.providerID = providerID
        self.fetchedAt = fetchedAt
        self.accountLabel = accountLabel
        self.windows = windows
        self.tokens = tokens
        self.detail = detail
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

import Foundation
import TokenOutCore

public struct CodexProvider: UsageProvider {
    public static let id = ProviderID.codex
    public let displayName = "Codex"

    public init() {}

    public func detectInstallation() async -> Bool {
        FileManager.default.fileExists(atPath: CodexAuthReader.fileURL.path)
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        let signedOutHelp = "Open a terminal, run `codex`, and sign in."
        guard var auth = CodexAuthReader.load() else {
            throw ProviderError.signedOut(help: signedOutHelp)
        }
        if auth.isExpired {
            guard let refreshed = await CodexAuthReader.refresh(auth) else {
                throw ProviderError.signedOut(help: signedOutHelp)
            }
            auth = refreshed
        }

        var data: Data
        do {
            data = try await CodexUsageAPI.fetch(token: auth.accessToken, accountID: auth.accountID)
        } catch ProviderError.signedOut {
            guard let refreshed = await CodexAuthReader.refresh(auth) else {
                throw ProviderError.signedOut(help: signedOutHelp)
            }
            auth = refreshed
            data = try await CodexUsageAPI.fetch(token: auth.accessToken, accountID: auth.accountID)
        }

        let windows = CodexUsageAPI.decodeWindows(from: data)
        guard !windows.isEmpty else {
            throw ProviderError.decoding("no rate-limit windows in usage response")
        }
        let plan = CodexUsageAPI.decodePlan(from: data) ?? auth.planType
        var detail = plan.map { [DetailLine(title: "Plan", value: $0.capitalized)] } ?? []
        if let credits = CodexUsageAPI.decodeCredits(from: data) {
            detail.append(DetailLine(title: "Credits", value: credits))
        }

        // Local session rollouts → tokens, cost estimate, by-model breakdown, daily chart.
        let sessions = await CodexSessionScanner.shared.recentSessions()
        let now = Date.now
        let startOfToday = Calendar.current.startOfDay(for: now)
        let weekStart = now.addingTimeInterval(-7 * 86400)
        var todayTokens = 0, weekTokens = 0
        var todayCost = 0.0, weekCost = 0.0
        var byModel: [String: (tokens: Int, cost: Double)] = [:]
        for session in sessions {
            let cost = CodexSessionScanner.cost(of: session)
            if session.date >= weekStart { weekTokens += session.totalTokens; weekCost += cost }
            if session.date >= startOfToday {
                todayTokens += session.totalTokens
                todayCost += cost
                var entry = byModel[session.model] ?? (0, 0)
                entry.tokens += session.totalTokens
                entry.cost += cost
                byModel[session.model] = entry
            }
        }
        var breakdowns: [Breakdown] = []
        if !byModel.isEmpty {
            let totalCost = max(todayCost, 0.001)
            breakdowns.append(Breakdown(title: "Today by model", rows: byModel
                .sorted { $0.value.cost > $1.value.cost }.prefix(4).map {
                    Breakdown.Row(name: $0.key,
                                  valueText: "\(Format.tokens($0.value.tokens)) · ~\(Format.usd($0.value.cost))",
                                  fraction: $0.value.cost / totalCost)
                }))
        }
        let daily = DayStat.aggregate(
            points: sessions.map {
                ($0.date, $0.totalTokens, CodexSessionScanner.cost(of: $0), $0.model)
            },
            days: 92, estimated: true)

        return UsageSnapshot(
            providerID: .codex,
            fetchedAt: now,
            accountLabel: plan?.capitalized,
            windows: windows,
            tokens: sessions.isEmpty ? nil : TokenTotals(
                todayTokens: todayTokens, weekTokens: weekTokens,
                todayCostUSD: todayCost, weekCostUSD: weekCost, costIsEstimated: true),
            detail: detail,
            breakdowns: breakdowns,
            daily: daily
        )
    }
}

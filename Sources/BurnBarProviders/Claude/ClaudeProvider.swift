import Foundation
import BurnBarCore

public struct ClaudeProvider: UsageProvider {
    public static let id = ProviderID.claude
    public let displayName = "Claude Code"

    public init() {}

    public func detectInstallation() async -> Bool {
        FileManager.default.fileExists(
            atPath: FileManager.default.homeDirectoryForCurrentUser
                .appending(path: ".claude").path)
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        let signedOutHelp = "Open a terminal, run `claude`, and sign in with /login."
        guard var creds = ClaudeCredentials.load() else {
            throw ProviderError.signedOut(help: signedOutHelp)
        }
        if creds.isExpired {
            guard let refreshed = await ClaudeCredentials.refresh(creds) else {
                throw ProviderError.signedOut(help: signedOutHelp)
            }
            creds = refreshed
        }

        var windows: [LimitWindow]
        do {
            windows = try await ClaudeUsageAPI.fetch(token: creds.accessToken)
        } catch ProviderError.signedOut {
            // Token rejected — one refresh attempt, then give up for this cycle.
            guard let refreshed = await ClaudeCredentials.refresh(creds) else {
                throw ProviderError.signedOut(help: signedOutHelp)
            }
            windows = try await ClaudeUsageAPI.fetch(token: refreshed.accessToken)
        }

        let entries = await ClaudeTranscriptScanner.shared.recentEntries()
        let now = Date.now
        let cal = Calendar.current
        let todayRange = cal.startOfDay(for: now)...now
        let today = ClaudeTranscriptParser.total(entries: entries, in: todayRange)
        let week = ClaudeTranscriptParser.total(
            entries: entries, in: now.addingTimeInterval(-7 * 86400)...now)

        var breakdowns: [Breakdown] = []
        let totalCostToday = max(today.costUSD, 0.01)
        let byModel = ClaudeTranscriptParser.totals(entries: entries, in: todayRange) {
            ClaudeTranscriptParser.modelFamily($0.model)
        }
        if byModel.count > 1 || (byModel.first.map { $0.costUSD > 0 } ?? false) {
            breakdowns.append(Breakdown(title: "Today by model", rows: byModel.prefix(4).map {
                Breakdown.Row(name: $0.name,
                              valueText: "\(Format.tokens($0.tokens.total)) · \(Format.usd($0.costUSD))",
                              fraction: $0.costUSD / totalCostToday)
            }))
        }
        let byProject = ClaudeTranscriptParser.totals(entries: entries, in: todayRange) {
            $0.project.isEmpty ? "other" : $0.project
        }
        if byProject.count > 1 {
            breakdowns.append(Breakdown(title: "Today by project", rows: byProject.prefix(4).map {
                Breakdown.Row(name: $0.name,
                              valueText: "\(Format.tokens($0.tokens.total)) · \(Format.usd($0.costUSD))",
                              fraction: $0.costUSD / totalCostToday)
            }))
        }

        return UsageSnapshot(
            providerID: .claude,
            fetchedAt: now,
            accountLabel: creds.subscriptionType?.capitalized,
            windows: windows,
            tokens: TokenTotals(
                todayTokens: today.tokens.total,
                weekTokens: week.tokens.total,
                todayCostUSD: today.costUSD,
                weekCostUSD: week.costUSD,
                costIsEstimated: today.costIsEstimated || week.costIsEstimated
            ),
            breakdowns: breakdowns
        )
    }
}

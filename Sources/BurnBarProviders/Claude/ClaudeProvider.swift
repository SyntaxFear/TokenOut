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
        let today = ClaudeTranscriptParser.total(entries: entries, in: cal.startOfDay(for: now)...now)
        let week = ClaudeTranscriptParser.total(
            entries: entries, in: now.addingTimeInterval(-7 * 86400)...now)

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
            )
        )
    }
}

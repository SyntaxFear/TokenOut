import Foundation
import BurnBarCore

/// In-memory holder for the last credentials that actually worked.
actor ClaudeTokenCache {
    static let shared = ClaudeTokenCache()
    private var creds: ClaudeOAuth?
    func get() -> ClaudeOAuth? { creds }
    func set(_ new: ClaudeOAuth?) { creds = new }
}

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

        // Token strategy: ADOPT Claude Code's live token, never preemptively refresh.
        // Anthropic rotates refresh tokens on use, so refreshing here invalidates the
        // CLI's copy and signs BOTH apps out — the "login every 30 minutes" bug.
        // The CLI refreshes its own token whenever the user works; we just re-read it.
        var candidates: [ClaudeOAuth] = []
        if let cached = await ClaudeTokenCache.shared.get() { candidates.append(cached) }
        guard let live = ClaudeCredentials.load() else {
            if ClaudeCredentials.keychainAccessBlocked {
                // Not a dead session — macOS is (still) gating the Keychain item.
                throw ProviderError.signedOut(help:
                    "macOS is blocking Keychain access. Click “Always Allow” on the prompt (relaunch BurnBar if it's gone).")
            }
            throw ProviderError.signedOut(help: signedOutHelp)
        }
        if !candidates.contains(where: { $0.accessToken == live.accessToken }) {
            candidates.append(live)
        }

        // Only a real 401 moves us to the next token; network/decoding failures
        // propagate as-is (stale card) and must NEVER trigger a refresh grant —
        // that's what used to burn the CLI's rotating refresh token.
        var windows: [LimitWindow]?
        var workingCreds: ClaudeOAuth = live
        for creds in candidates {
            do {
                windows = try await ClaudeUsageAPI.fetch(token: creds.accessToken)
                workingCreds = creds
                break
            } catch ProviderError.signedOut {
                continue
            }
        }
        if windows == nil {
            // Every candidate got a true 401: one refresh grant, cached for reuse.
            guard let refreshed = await ClaudeCredentials.refresh(live) else {
                await ClaudeTokenCache.shared.set(nil)
                throw ProviderError.signedOut(help: signedOutHelp)
            }
            do {
                windows = try await ClaudeUsageAPI.fetch(token: refreshed.accessToken)
                workingCreds = refreshed
            } catch ProviderError.signedOut {
                await ClaudeTokenCache.shared.set(nil)
                throw ProviderError.signedOut(help: signedOutHelp)
            }
        }
        await ClaudeTokenCache.shared.set(workingCreds)
        let creds = workingCreds
        guard let windows else { throw ProviderError.signedOut(help: signedOutHelp) }

        let entries = await ClaudeTranscriptScanner.shared.recentEntries(withinDays: 92)
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
            breakdowns: breakdowns,
            daily: DayStat.aggregate(
                points: entries.map {
                    ($0.timestamp, $0.usage.total, Pricing.cost(model: $0.model, usage: $0.usage).usd,
                     ClaudeTranscriptParser.modelFamily($0.model))
                },
                days: 92)
        )
    }
}

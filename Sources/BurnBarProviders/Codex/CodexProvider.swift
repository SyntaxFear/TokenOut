import Foundation
import BurnBarCore

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
        return UsageSnapshot(
            providerID: .codex,
            fetchedAt: .now,
            accountLabel: plan?.capitalized,
            windows: windows,
            tokens: nil,
            detail: detail
        )
    }
}

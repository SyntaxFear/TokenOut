import Foundation

/// Every tracked tool implements this. Adding a provider = one conforming type + one registry entry.
public protocol UsageProvider: Sendable {
    static var id: ProviderID { get }
    var displayName: String { get }
    /// Is the tool present on this Mac? Uninstalled tools are hidden from the UI.
    func detectInstallation() async -> Bool
    /// Fetch current usage, normalized. Throw ProviderError for expected failure modes.
    func fetchUsage() async throws -> UsageSnapshot
}

public enum ProviderError: Error, Sendable, Equatable {
    case signedOut(help: String)
    case unsupported(reason: String)
    case network(String)
    case decoding(String)
}

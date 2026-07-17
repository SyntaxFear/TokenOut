import Foundation
import Security
import Darwin

public struct ClaudeOAuth: Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    /// Epoch milliseconds, as stored by Claude Code.
    public var expiresAt: Double?
    public var subscriptionType: String?
    public var scopes: [String]
    public var rateLimitTier: String?
    public var clientID: String?

    public init(accessToken: String, refreshToken: String?, expiresAt: Double?,
                subscriptionType: String?, scopes: [String] = [],
                rateLimitTier: String? = nil, clientID: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.subscriptionType = subscriptionType
        self.scopes = scopes
        self.rateLimitTier = rateLimitTier
        self.clientID = clientID
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt / 1000 < Date.now.timeIntervalSince1970 + 60
    }
}

/// Shares Claude Code's OAuth credential safely. Refresh grants rotate the refresh
/// token, so BurnBar must use Claude Code's scope set, hold the same lock paths, and
/// persist the complete rotated credential back to the source it read.
public enum ClaudeCredentials {
    static let keychainService = "Claude Code-credentials"
    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".claude/.credentials.json")
    static let refreshLockURLs = [
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/.oauth_refresh.lock"),
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude.lock"),
    ]

    /// Public first-party OAuth client used by Claude Code.
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let tokenEndpoint = URL(string: "https://platform.claude.com/v1/oauth/token")!
    static let defaultScopes = [
        "user:profile",
        "user:inference",
        "user:sessions:claude_code",
        "user:mcp_servers",
        "user:file_upload",
    ]

    private enum Source: Sendable { case keychain, file }
    private struct Record: Sendable {
        var data: Data
        var source: Source
        var credentials: ClaudeOAuth
    }

    private struct RefreshLock: Sendable {
        var urls: [URL]

        func release() {
            for url in urls.reversed() {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    public static func load() -> ClaudeOAuth? {
        loadRecord()?.credentials
    }

    /// Set by every keychain read/write so callers can distinguish a missing session
    /// from macOS denying or waiting on the Keychain ACL prompt.
    nonisolated(unsafe) static var lastKeychainStatus: OSStatus = errSecSuccess

    static var keychainAccessBlocked: Bool {
        [errSecAuthFailed, errSecUserCanceled, errSecInteractionNotAllowed]
            .contains(lastKeychainStatus)
    }

    static func fromKeychain() -> ClaudeOAuth? {
        guard let data = keychainData() else { return nil }
        return parse(data)
    }

    static func fromFile() -> ClaudeOAuth? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return parse(data)
    }

    static func parse(_ data: Data) -> ClaudeOAuth? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let access = nonEmpty(oauth["accessToken"] as? String)
        else { return nil }

        return ClaudeOAuth(
            accessToken: access,
            refreshToken: nonEmpty(oauth["refreshToken"] as? String),
            expiresAt: (oauth["expiresAt"] as? NSNumber)?.doubleValue,
            subscriptionType: oauth["subscriptionType"] as? String,
            scopes: oauth["scopes"] as? [String] ?? [],
            rateLimitTier: oauth["rateLimitTier"] as? String,
            clientID: nonEmpty(oauth["clientId"] as? String)
        )
    }

    /// Refreshes and immediately persists the rotated credential. This mirrors the
    /// installed Claude Code client's first-party refresh contract: exact endpoint,
    /// complete scope set, and shared lock paths. Returning an in-memory-only rotated
    /// token would invalidate Claude Code's stored refresh token on its next request.
    public static func refresh(_ staleCredentials: ClaudeOAuth) async -> ClaudeOAuth? {
        guard nonEmpty(staleCredentials.refreshToken) != nil,
              let lock = await acquireRefreshLock()
        else { return nil }
        defer { lock.release() }

        // Another Claude/BurnBar process may have refreshed while we waited.
        guard let record = loadRecord() else { return nil }
        let current = record.credentials
        if current.accessToken != staleCredentials.accessToken {
            return current
        }
        guard let refreshToken = nonEmpty(current.refreshToken) else { return nil }

        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = refreshRequestBody(credentials: current, refreshToken: refreshToken)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = nonEmpty(json["access_token"] as? String)
        else { return nil }

        let expiresIn = (json["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        let responseScopes = (json["scope"] as? String)?
            .split(separator: " ").map(String.init) ?? current.scopes
        let refreshed = ClaudeOAuth(
            accessToken: access,
            refreshToken: nonEmpty(json["refresh_token"] as? String) ?? refreshToken,
            expiresAt: (Date.now.timeIntervalSince1970 + expiresIn) * 1000,
            subscriptionType: current.subscriptionType,
            scopes: responseScopes,
            rateLimitTier: current.rateLimitTier,
            clientID: current.clientID
        )

        guard persist(refreshed, replacing: record) else { return nil }
        return refreshed
    }

    static func refreshRequestBody(credentials: ClaudeOAuth, refreshToken: String) -> Data? {
        try? JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": credentials.clientID ?? clientID,
            "scope": refreshScopes(for: credentials).joined(separator: " "),
        ])
    }

    static func refreshScopes(for credentials: ClaudeOAuth) -> [String] {
        // Claude Code treats subscription credentials without a custom client id as
        // first-party and restores its complete default scope set during refresh.
        let source = credentials.clientID == nil && credentials.subscriptionType != nil
            ? defaultScopes + credentials.scopes
            : credentials.scopes
        var seen: Set<String> = []
        return source.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static func updatedCredentialData(_ original: Data, with credentials: ClaudeOAuth) -> Data? {
        guard var root = try? JSONSerialization.jsonObject(with: original) as? [String: Any],
              var oauth = root["claudeAiOauth"] as? [String: Any]
        else { return nil }

        oauth["accessToken"] = credentials.accessToken
        oauth["refreshToken"] = credentials.refreshToken ?? ""
        oauth["expiresAt"] = credentials.expiresAt ?? 0
        oauth["scopes"] = credentials.scopes
        if let subscriptionType = credentials.subscriptionType {
            oauth["subscriptionType"] = subscriptionType
        }
        if let rateLimitTier = credentials.rateLimitTier {
            oauth["rateLimitTier"] = rateLimitTier
        }
        if let clientID = credentials.clientID {
            oauth["clientId"] = clientID
        }
        root["claudeAiOauth"] = oauth
        return try? JSONSerialization.data(withJSONObject: root)
    }

    private static func loadRecord() -> Record? {
        if let data = keychainData(), let credentials = parse(data) {
            return Record(data: data, source: .keychain, credentials: credentials)
        }
        if let data = try? Data(contentsOf: fileURL), let credentials = parse(data) {
            return Record(data: data, source: .file, credentials: credentials)
        }
        return nil
    }

    private static func keychainData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        lastKeychainStatus = status
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func persist(_ credentials: ClaudeOAuth, replacing record: Record) -> Bool {
        guard let data = updatedCredentialData(record.data, with: credentials) else { return false }
        switch record.source {
        case .keychain:
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
            ]
            let updates: [String: Any] = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
            lastKeychainStatus = status
            return status == errSecSuccess
        case .file:
            do {
                try data.write(to: fileURL, options: [.atomic])
                return true
            } catch {
                return false
            }
        }
    }

    private static func acquireRefreshLock() async -> RefreshLock? {
        for attempt in 0..<6 {
            var acquired: [URL] = []
            var failed = false
            for url in refreshLockURLs {
                removeStaleLock(at: url)
                let descriptor = url.path.withCString {
                    Darwin.open($0, O_CREAT | O_EXCL | O_WRONLY, S_IRUSR | S_IWUSR)
                }
                if descriptor >= 0 {
                    Darwin.close(descriptor)
                    acquired.append(url)
                } else {
                    failed = true
                    break
                }
            }
            if !failed { return RefreshLock(urls: acquired) }
            for url in acquired.reversed() { try? FileManager.default.removeItem(at: url) }
            if attempt < 5 {
                try? await Task.sleep(for: .milliseconds(350 + attempt * 200))
            }
        }
        return nil
    }

    private static func removeStaleLock(at url: URL) {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let modified = values.contentModificationDate,
              Date.now.timeIntervalSince(modified) > 30
        else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}

import Foundation
import Security

public struct ClaudeOAuth: Sendable {
    public var accessToken: String
    public var refreshToken: String?
    /// Epoch milliseconds, as stored by Claude Code.
    public var expiresAt: Double?
    public var subscriptionType: String?

    public init(accessToken: String, refreshToken: String?, expiresAt: Double?, subscriptionType: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.subscriptionType = subscriptionType
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt / 1000 < Date.now.timeIntervalSince1970 + 60
    }
}

/// Read-only access to Claude Code's stored OAuth credentials.
/// Keychain first (macOS default), credentials file as fallback. Never written back.
public enum ClaudeCredentials {
    static let keychainService = "Claude Code-credentials"
    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".claude/.credentials.json")
    /// Public OAuth client id used by Claude Code's own login flow.
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let tokenEndpoints = [
        URL(string: "https://console.anthropic.com/v1/oauth/token")!,
        URL(string: "https://platform.claude.com/v1/oauth/token")!,
    ]

    public static func load() -> ClaudeOAuth? {
        fromKeychain() ?? fromFile()
    }

    /// Set by every keychain read so callers can tell "no item" from "access blocked".
    nonisolated(unsafe) static var lastKeychainStatus: OSStatus = errSecSuccess

    /// True when the last failure was macOS denying/awaiting the ACL prompt,
    /// not a missing or dead credential.
    static var keychainAccessBlocked: Bool {
        [errSecAuthFailed, errSecUserCanceled, errSecInteractionNotAllowed]
            .contains(lastKeychainStatus)
    }

    static func fromKeychain() -> ClaudeOAuth? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        lastKeychainStatus = status
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return parse(data)
    }

    static func fromFile() -> ClaudeOAuth? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return parse(data)
    }

    static func parse(_ data: Data) -> ClaudeOAuth? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let access = oauth["accessToken"] as? String else { return nil }
        return ClaudeOAuth(
            accessToken: access,
            refreshToken: oauth["refreshToken"] as? String,
            expiresAt: (oauth["expiresAt"] as? NSNumber)?.doubleValue,
            subscriptionType: oauth["subscriptionType"] as? String
        )
    }

    /// Best-effort refresh, trying the known Claude Code OAuth endpoints. In-memory
    /// only — we never mutate Claude Code's stored credentials. When BurnBar can't get
    /// a valid token, the honest recovery is for the user to run Claude Code (which
    /// refreshes the shared token) — see ClaudeProvider.
    public static func refresh(_ creds: ClaudeOAuth) async -> ClaudeOAuth? {
        guard let refreshToken = creds.refreshToken else { return nil }
        for endpoint in tokenEndpoints {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: [
                "grant_type": "refresh_token",
                "refresh_token": refreshToken,
                "client_id": clientID,
            ])
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let access = json["access_token"] as? String else { continue }
            let expiresIn = (json["expires_in"] as? NSNumber)?.doubleValue ?? 3600
            return ClaudeOAuth(
                accessToken: access,
                refreshToken: (json["refresh_token"] as? String) ?? refreshToken,
                expiresAt: (Date.now.timeIntervalSince1970 + expiresIn) * 1000,
                subscriptionType: creds.subscriptionType
            )
        }
        return nil
    }
}

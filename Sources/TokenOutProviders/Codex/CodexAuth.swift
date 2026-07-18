import Foundation

public struct CodexAuth: Sendable {
    public var accessToken: String
    public var refreshToken: String?
    public var accountID: String?
    public var planType: String?
    public var expiresAt: Date?

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date.now.addingTimeInterval(60)
    }
}

/// Read-only reader for Codex CLI's ~/.codex/auth.json. Never written back.
public enum CodexAuthReader {
    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".codex/auth.json")
    /// Codex CLI's public OAuth client id.
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let tokenEndpoint = URL(string: "https://auth.openai.com/oauth/token")!

    public static func load() -> CodexAuth? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return parse(data)
    }

    public static func parse(_ data: Data) -> CodexAuth? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let access = tokens["access_token"] as? String else { return nil }

        var accountID = tokens["account_id"] as? String
        var plan: String?
        var expiresAt: Date?
        if let payload = decodeJWTPayload(access) {
            if let exp = (payload["exp"] as? NSNumber)?.doubleValue {
                expiresAt = Date(timeIntervalSince1970: exp)
            }
            if let authClaims = payload["https://api.openai.com/auth"] as? [String: Any] {
                plan = authClaims["chatgpt_plan_type"] as? String
                accountID = accountID ?? authClaims["chatgpt_account_id"] as? String
            }
        }
        return CodexAuth(accessToken: access,
                         refreshToken: tokens["refresh_token"] as? String,
                         accountID: accountID, planType: plan, expiresAt: expiresAt)
    }

    static func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Best-effort refresh; result lives in memory only.
    public static func refresh(_ auth: CodexAuth) async -> CodexAuth? {
        guard let refreshToken = auth.refreshToken else { return nil }
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
            "scope": "openid profile email",
        ])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String else { return nil }
        let payload: [String: Any] = [
            "tokens": ["access_token": access,
                       "refresh_token": (json["refresh_token"] as? String) ?? refreshToken] as [String: Any],
        ]
        guard let encoded = try? JSONSerialization.data(withJSONObject: payload),
              var refreshed = parse(encoded) else { return nil }
        refreshed.accountID = refreshed.accountID ?? auth.accountID
        refreshed.planType = refreshed.planType ?? auth.planType
        return refreshed
    }
}

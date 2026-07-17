import Foundation
import BurnBarCore

/// Decodes the ChatGPT backend usage endpoint Codex itself uses.
/// Tolerant: windows are labeled by their duration, unknown fields ignored.
public enum CodexUsageAPI {
    static let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    public static func decodeWindows(from data: Data, now: Date = .now) -> [LimitWindow] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        let rateLimits = (root["rate_limits"] as? [String: Any]) ?? root
        var windows: [LimitWindow] = []
        for key in ["primary", "secondary"] {
            guard let dict = rateLimits[key] as? [String: Any] else { continue }
            guard let percent = (dict["used_percent"] as? NSNumber)?.doubleValue else { continue }
            let windowMinutes = (dict["window_minutes"] as? NSNumber)?.intValue ?? 0
            let resetsIn = (dict["resets_in_seconds"] as? NSNumber)?.doubleValue
            let isSession = windowMinutes > 0 && windowMinutes <= 360
            windows.append(LimitWindow(
                label: isSession ? "5-hour session" : "Weekly",
                kind: isSession ? .session : .weekly,
                usedFraction: percent / 100.0,
                resetsAt: resetsIn.map { now.addingTimeInterval($0) }
            ))
        }
        return windows
    }

    public static func decodePlan(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return root["plan_type"] as? String
    }

    public static func fetch(token: String, accountID: String?) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let accountID {
            request.setValue(accountID, forHTTPHeaderField: "chatgpt-account-id")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.network("no HTTP response")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw ProviderError.signedOut(help: "")
        }
        guard http.statusCode == 200 else {
            throw ProviderError.network("HTTP \(http.statusCode)")
        }
        return data
    }
}

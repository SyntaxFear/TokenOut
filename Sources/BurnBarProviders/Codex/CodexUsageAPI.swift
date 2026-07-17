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
        // Live shape (verified 2026-07-17): rate_limit.{primary_window,secondary_window};
        // older/alternate shape kept as fallback: rate_limits.{primary,secondary}.
        let container = (root["rate_limit"] as? [String: Any])
            ?? (root["rate_limits"] as? [String: Any]) ?? root
        var windows: [LimitWindow] = []
        for keys in [["primary_window", "primary"], ["secondary_window", "secondary"]] {
            guard let dict = keys.lazy.compactMap({ container[$0] as? [String: Any] }).first,
                  let percent = (dict["used_percent"] as? NSNumber)?.doubleValue else { continue }

            var durationSeconds = (dict["limit_window_seconds"] as? NSNumber)?.doubleValue ?? 0
            if durationSeconds == 0,
               let minutes = (dict["window_minutes"] as? NSNumber)?.doubleValue {
                durationSeconds = minutes * 60
            }

            var resetsAt: Date?
            if let epoch = (dict["reset_at"] as? NSNumber)?.doubleValue {
                resetsAt = Date(timeIntervalSince1970: epoch)
            } else if let after = ((dict["reset_after_seconds"] ?? dict["resets_in_seconds"]) as? NSNumber)?.doubleValue {
                resetsAt = now.addingTimeInterval(after)
            }

            let (label, kind): (String, LimitWindow.Kind) = switch durationSeconds {
            case 1...(6 * 3600): ("5-hour session", .session)
            case ...(10 * 86400): ("Weekly", .weekly)
            default: ("Monthly", .weekly)
            }
            windows.append(LimitWindow(label: label, kind: kind,
                                       usedFraction: percent / 100.0, resetsAt: resetsAt))
        }
        return windows
    }

    public static func decodePlan(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return root["plan_type"] as? String
    }

    /// Human-readable credits line, when the account has any credit signal worth showing.
    public static func decodeCredits(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let credits = root["credits"] as? [String: Any] else { return nil }
        if (credits["unlimited"] as? Bool) == true { return "Unlimited" }
        if let balance = (credits["balance"] as? NSNumber)?.doubleValue {
            return Format.usd(balance)
        }
        if (credits["has_credits"] as? Bool) == true { return "Available" }
        return nil
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

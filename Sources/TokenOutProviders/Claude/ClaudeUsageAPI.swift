import Foundation
import TokenOutCore

/// Decodes Claude's OAuth usage endpoint into normalized windows.
/// Tolerant by design: unknown keys are ignored, utilization accepted as 0-100 or 0-1,
/// missing resets_at allowed — undocumented endpoints drift.
public enum ClaudeUsageAPI {
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static let knownWindows: [(key: String, label: String, kind: LimitWindow.Kind)] = [
        ("five_hour", "5-hour session", .session),
        ("seven_day", "Weekly (all models)", .weekly),
        ("seven_day_sonnet", "Weekly (Sonnet)", .weekly),
        ("seven_day_opus", "Weekly (Opus)", .weekly),
        ("seven_day_oauth_apps", "Weekly (apps)", .weekly),
    ]

    /// Claude's window lengths are fixed by kind; the API doesn't send them.
    static func duration(for kind: LimitWindow.Kind) -> TimeInterval? {
        switch kind {
        case .session: 5 * 3600
        case .weekly: 7 * 86_400
        case .credits: nil
        }
    }

    public static func decodeWindows(from data: Data) -> [LimitWindow] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        // Preferred source (verified live 2026-07-17): the `limits` array — it includes
        // per-model scoped windows the flat keys don't carry.
        if let limits = root["limits"] as? [[String: Any]] {
            let windows = limits.compactMap(decodeLimitEntry)
            if !windows.isEmpty { return windows }
        }
        // Fallback: flat window keys (older response shape).
        var windows: [LimitWindow] = []
        for known in knownWindows {
            guard let dict = root[known.key] as? [String: Any] else { continue }
            guard let raw = (dict["utilization"] as? NSNumber)?.doubleValue else { continue }
            let fraction = raw / 100.0  // flat shape documents utilization as 0-100 percent
            let resetsAt = (dict["resets_at"] as? String).flatMap {
                ClaudeTranscriptParser.date(from: $0)
            }
            windows.append(LimitWindow(label: known.label, kind: known.kind,
                                       usedFraction: fraction, resetsAt: resetsAt,
                                       duration: duration(for: known.kind)))
        }
        return windows
    }

    static func decodeLimitEntry(_ dict: [String: Any]) -> LimitWindow? {
        guard let raw = (dict["percent"] as? NSNumber)?.doubleValue else { return nil }
        let kindString = (dict["kind"] as? String) ?? (dict["group"] as? String) ?? "weekly"
        let kind: LimitWindow.Kind = kindString == "session" ? .session : .weekly
        let scopedModel = ((dict["scope"] as? [String: Any])?["model"] as? [String: Any])?["display_name"] as? String
        let label: String = switch kindString {
        case "session": "5-hour session"
        case "weekly_all": "Weekly (all models)"
        case "weekly_scoped": "Weekly (\(scopedModel ?? "scoped"))"
        default: kindString.replacingOccurrences(of: "_", with: " ").capitalized
        }
        let resetsAt = (dict["resets_at"] as? String).flatMap {
            ClaudeTranscriptParser.date(from: $0)
        }
        return LimitWindow(label: label, kind: kind, usedFraction: raw / 100.0,
                           resetsAt: resetsAt, duration: duration(for: kind))
    }

    public static func fetch(token: String) async throws -> [LimitWindow] {
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.network("no HTTP response")
        }
        if http.statusCode == 401 { throw ProviderError.signedOut(help: "") }
        if http.statusCode == 429 {
            throw ProviderError.rateLimited(retryAfter: retryAfterSeconds(http))
        }
        guard http.statusCode == 200 else {
            throw ProviderError.network("HTTP \(http.statusCode)")
        }
        let windows = decodeWindows(from: data)
        guard !windows.isEmpty else {
            throw ProviderError.decoding("no known windows in usage response")
        }
        return windows
    }
}

/// Retry-After can be seconds or an HTTP date; only the seconds form is worth parsing.
private func retryAfterSeconds(_ http: HTTPURLResponse) -> TimeInterval? {
    (http.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init)
}

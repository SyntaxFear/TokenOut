import Foundation
import BurnBarCore

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

    public static func decodeWindows(from data: Data) -> [LimitWindow] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        var windows: [LimitWindow] = []
        for known in knownWindows {
            guard let dict = root[known.key] as? [String: Any] else { continue }
            guard let raw = (dict["utilization"] as? NSNumber)?.doubleValue else { continue }
            let fraction = raw > 1.5 ? raw / 100.0 : raw
            let resetsAt = (dict["resets_at"] as? String).flatMap {
                ClaudeTranscriptParser.date(from: $0)
            }
            windows.append(LimitWindow(label: known.label, kind: known.kind,
                                       usedFraction: fraction, resetsAt: resetsAt))
        }
        return windows
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

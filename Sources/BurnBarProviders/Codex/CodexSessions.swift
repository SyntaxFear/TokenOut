import Foundation
import BurnBarCore

/// One Codex CLI session's final cumulative usage.
public struct CodexSessionStat: Sendable {
    public var date: Date
    public var model: String
    public var input: Int
    public var cachedInput: Int
    public var output: Int
    public var totalTokens: Int
}

/// Scans ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl for per-session token totals.
/// Each rollout carries cumulative `token_count` events; the last one is the session total.
public actor CodexSessionScanner {
    public static let shared = CodexSessionScanner()
    private var cache: [String: (mtime: Date, stat: CodexSessionStat?)] = [:]
    /// Live sessions plus the archive Codex moves older rollouts into — without the
    /// archive, most of the day-by-day history is invisible.
    private let roots = [".codex/sessions", ".codex/archived_sessions"].map {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: $0)
    }

    /// Estimated API-equivalent pricing for the GPT-5 family, USD per MTok.
    static func cost(of stat: CodexSessionStat) -> Double {
        (Double(stat.input - stat.cachedInput) * 1.25
         + Double(stat.cachedInput) * 0.125
         + Double(stat.output) * 10.0) / 1_000_000
    }

    public func recentSessions(withinDays days: Int = 92) -> [CodexSessionStat] {
        let cutoff = Date.now.addingTimeInterval(-Double(days) * 86400)
        var stats: [CodexSessionStat] = []
        var liveKeys: Set<String> = []
        let urls = roots.flatMap { root -> [URL] in
            guard let enumerator = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]) else { return [] }
            return enumerator.compactMap { $0 as? URL }
        }
        for url in urls
        where url.lastPathComponent.hasPrefix("rollout-") && url.pathExtension == "jsonl" {
            guard let mtime = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate, mtime > cutoff else { continue }
            let key = url.path
            liveKeys.insert(key)
            if let cached = cache[key], cached.mtime == mtime {
                if let stat = cached.stat { stats.append(stat) }
            } else {
                let stat = Self.parseRollout(at: url, fallbackDate: mtime)
                cache[key] = (mtime, stat)
                if let stat { stats.append(stat) }
            }
        }
        cache = cache.filter { liveKeys.contains($0.key) }
        return stats
    }

    /// Reads the last cumulative token_count and the last model mention.
    static func parseRollout(at url: URL, fallbackDate: Date) -> CodexSessionStat? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return parseRollout(text: text,
                            date: dateFromFilename(url.lastPathComponent) ?? fallbackDate)
    }

    static func dateFromFilename(_ name: String) -> Date? {
        // rollout-2026-07-16T23-08-39-<uuid>.jsonl → midday of that date (local).
        guard let match = name.firstMatch(of: /rollout-(\d{4})-(\d{2})-(\d{2})T/) else { return nil }
        var parts = DateComponents()
        parts.year = Int(match.1); parts.month = Int(match.2); parts.day = Int(match.3)
        parts.hour = 12
        return Calendar.current.date(from: parts)
    }

    static func parseRollout(text: String, date: Date) -> CodexSessionStat? {
        var lastUsage: [String: Any]?
        var model = "gpt-5"
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.contains("\"token_count\"") {
                if let data = line.data(using: .utf8),
                   let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let payload = root["payload"] as? [String: Any],
                   let info = payload["info"] as? [String: Any],
                   let total = info["total_token_usage"] as? [String: Any] {
                    lastUsage = total
                }
            } else if line.contains("\"turn_context\"") {
                if let data = line.data(using: .utf8),
                   let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let payload = root["payload"] as? [String: Any],
                   let m = payload["model"] as? String {
                    model = m
                }
            }
        }
        guard let usage = lastUsage else { return nil }
        func int(_ key: String) -> Int { (usage[key] as? NSNumber)?.intValue ?? 0 }
        let input = int("input_tokens")
        let cached = int("cached_input_tokens")
        let output = int("output_tokens")
        let total = int("total_tokens")
        guard total > 0 || input + output > 0 else { return nil }
        return CodexSessionStat(date: date, model: model, input: input, cachedInput: cached,
                                output: output, totalTokens: max(total, input + output))
    }
}

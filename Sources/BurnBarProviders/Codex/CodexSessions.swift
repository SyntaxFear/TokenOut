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

    /// API-equivalent pricing, USD per MTok, verified against published OpenAI rates
    /// (2026-07): GPT-5.6 Sol 5/30, Terra 2.5/15, Luna 1/6, GPT-5.5 5/30; cached
    /// input reads bill at 10% of the input rate. Older gpt-5 fallback 1.25/10.
    static let rates: [(prefix: String, input: Double, output: Double)] = [
        ("gpt-5.6-sol", 5.0, 30.0),
        ("gpt-5.6-terra", 2.5, 15.0),
        ("gpt-5.6-luna", 1.0, 6.0),
        ("gpt-5.6", 5.0, 30.0),
        ("gpt-5.5", 5.0, 30.0),
        ("gpt-5", 1.25, 10.0),
    ]

    static func cost(of stat: CodexSessionStat) -> Double {
        let rate = rates.first { stat.model.hasPrefix($0.prefix) }
            ?? (prefix: "", input: 5.0, output: 30.0)  // unknown future models: current top tier
        return (Double(stat.input - stat.cachedInput) * rate.input
                + Double(stat.cachedInput) * rate.input * 0.1
                + Double(stat.output) * rate.output) / 1_000_000
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
        var seenNames: Set<String> = []
        for url in urls
        where url.lastPathComponent.hasPrefix("rollout-") && url.pathExtension == "jsonl" {
            // A rollout can transiently exist in both sessions/ and archived_sessions/;
            // filenames are UUID-unique, so first root (live) wins.
            guard seenNames.insert(url.lastPathComponent).inserted else { continue }
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

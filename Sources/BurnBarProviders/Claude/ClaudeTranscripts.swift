import Foundation
import BurnBarCore

/// One deduplicated assistant turn with usage.
public struct TranscriptEntry: Sendable {
    public var messageID: String
    public var model: String
    public var timestamp: Date
    public var usage: TokenUsage
}

public enum ClaudeTranscriptParser {
    nonisolated(unsafe) private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let isoPlain = ISO8601DateFormatter()

    static func date(from string: String) -> Date? {
        if let parsed = isoFractional.date(from: string) ?? isoPlain.date(from: string) {
            return parsed
        }
        // Some endpoints emit 6-digit fractional seconds; trim to millis and retry.
        let trimmed = string.replacing(/\.(\d{3})\d+/) { ".\($0.output.1)" }
        return isoFractional.date(from: trimmed) ?? isoPlain.date(from: trimmed)
    }

    /// Parse one transcript's JSONL text. Malformed lines and entries without usage are
    /// skipped; streamed duplicates (same message id) keep the last occurrence.
    public static func parse(_ text: String) -> [TranscriptEntry] {
        var byID: [String: TranscriptEntry] = [:]
        var order: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  root["type"] as? String == "assistant",
                  let message = root["message"] as? [String: Any],
                  let usageDict = message["usage"] as? [String: Any],
                  let tsString = root["timestamp"] as? String,
                  let ts = date(from: tsString)
            else { continue }

            func int(_ key: String, in dict: [String: Any]) -> Int {
                (dict[key] as? NSNumber)?.intValue ?? 0
            }
            let cacheCreation = usageDict["cache_creation"] as? [String: Any]
            let totalCacheWrite = int("cache_creation_input_tokens", in: usageDict)
            let write1h = cacheCreation.map { int("ephemeral_1h_input_tokens", in: $0) } ?? 0
            let write5m = cacheCreation.map { int("ephemeral_5m_input_tokens", in: $0) }
                ?? totalCacheWrite  // no breakdown → assume 5m (older Claude Code versions)

            let usage = TokenUsage(
                input: int("input_tokens", in: usageDict),
                output: int("output_tokens", in: usageDict),
                cacheWrite: write5m,
                cacheWrite1h: write1h,
                cacheRead: int("cache_read_input_tokens", in: usageDict)
            )
            let id = (message["id"] as? String) ?? (root["uuid"] as? String) ?? UUID().uuidString
            if byID[id] == nil { order.append(id) }
            byID[id] = TranscriptEntry(
                messageID: id,
                model: (message["model"] as? String) ?? "unknown",
                timestamp: ts,
                usage: usage
            )
        }
        return order.compactMap { byID[$0] }
    }

    public struct Totals: Sendable {
        public var tokens = TokenUsage()
        public var costUSD = 0.0
        public var costIsEstimated = false
    }

    public static func total(entries: [TranscriptEntry], in range: ClosedRange<Date>) -> Totals {
        var result = Totals()
        for entry in entries where range.contains(entry.timestamp) {
            result.tokens = result.tokens + entry.usage
            let cost = Pricing.cost(model: entry.model, usage: entry.usage)
            result.costUSD += cost.usd
            if cost.isEstimated { result.costIsEstimated = true }
        }
        return result
    }
}

/// Scans ~/.claude/projects incrementally, caching per-file parses by (path, mtime).
public actor ClaudeTranscriptScanner {
    public static let shared = ClaudeTranscriptScanner()
    private var cache: [String: (mtime: Date, entries: [TranscriptEntry])] = [:]

    private let projectsURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".claude/projects")

    public func recentEntries(withinDays days: Int = 8) -> [TranscriptEntry] {
        let cutoff = Date.now.addingTimeInterval(-Double(days) * 86400)
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: projectsURL,
                                             includingPropertiesForKeys: [.contentModificationDateKey],
                                             options: [.skipsHiddenFiles]) else { return [] }
        var all: [TranscriptEntry] = []
        var liveKeys: Set<String> = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let mtime = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate, mtime > cutoff else { continue }
            let key = url.path
            liveKeys.insert(key)
            if let cached = cache[key], cached.mtime == mtime {
                all.append(contentsOf: cached.entries)
            } else if let text = try? String(contentsOf: url, encoding: .utf8) {
                let entries = ClaudeTranscriptParser.parse(text)
                cache[key] = (mtime, entries)
                all.append(contentsOf: entries)
            }
        }
        cache = cache.filter { liveKeys.contains($0.key) }
        return all
    }
}

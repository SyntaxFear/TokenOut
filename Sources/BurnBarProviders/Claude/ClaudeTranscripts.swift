import Foundation
import BurnBarCore

/// One deduplicated assistant turn with usage.
public struct TranscriptEntry: Sendable {
    public var messageID: String
    public var model: String
    public var timestamp: Date
    public var usage: TokenUsage
    /// Display name of the project the session belongs to ("" when unknown).
    public var project: String = ""
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

    /// Turns Claude Code's encoded project dir ("-Users-x-Desktop-my-app") into a
    /// readable label ("my-app") by stripping known location prefixes.
    public static func projectLabel(fromEncodedDir dir: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
            .replacingOccurrences(of: "/", with: "-")
        var prefixes = ["Desktop", "Documents", "Downloads", "Developer", "Projects", "src", "code"]
            .map { "\(home)-\($0)-" }
        prefixes.append("\(home)-")
        for prefix in prefixes where dir.hasPrefix(prefix) {
            let stripped = String(dir.dropFirst(prefix.count))
            if !stripped.isEmpty { return stripped }
        }
        return dir.hasPrefix("-") ? String(dir.dropFirst()) : dir
    }

    /// Parse one transcript's JSONL text. Malformed lines and entries without usage are
    /// skipped; streamed duplicates (same message id) keep the last occurrence.
    public static func parse(_ text: String, project: String = "") -> [TranscriptEntry] {
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
                usage: usage,
                project: project
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

    public struct GroupTotal: Sendable, Equatable {
        public var name: String
        public var tokens: TokenUsage
        public var costUSD: Double
    }

    /// Cost/token totals grouped by a key (model family or project), sorted by cost desc.
    public static func totals(entries: [TranscriptEntry], in range: ClosedRange<Date>,
                              by key: (TranscriptEntry) -> String) -> [GroupTotal] {
        var groups: [String: GroupTotal] = [:]
        for entry in entries where range.contains(entry.timestamp) {
            let name = key(entry)
            var group = groups[name] ?? GroupTotal(name: name, tokens: TokenUsage(), costUSD: 0)
            group.tokens = group.tokens + entry.usage
            group.costUSD += Pricing.cost(model: entry.model, usage: entry.usage).usd
            groups[name] = group
        }
        return groups.values.sorted { $0.costUSD > $1.costUSD }
    }

    /// "claude-opus-4-8" → "Opus 4.8", "claude-fable-5" → "Fable 5".
    public static func modelFamily(_ id: String) -> String {
        let trimmed = id.hasPrefix("claude-") ? String(id.dropFirst(7)) : id
        let parts = trimmed.split(separator: "-").prefix { $0.range(of: #"^\d{8}$"#, options: .regularExpression) == nil }
        let name = parts.enumerated().map { index, part in
            index == 0 ? part.capitalized : String(part)
        }.joined(separator: " ")
        return name.replacingOccurrences(of: #" (\d) (\d)"#, with: " $1.$2", options: .regularExpression)
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
                let project = ClaudeTranscriptParser.projectLabel(
                    fromEncodedDir: url.deletingLastPathComponent().lastPathComponent)
                let entries = ClaudeTranscriptParser.parse(text, project: project)
                cache[key] = (mtime, entries)
                all.append(contentsOf: entries)
            }
        }
        cache = cache.filter { liveKeys.contains($0.key) }
        return all
    }
}

import Foundation
import SQLite3
import TokenOutCore

/// One model generation extracted from a conversation DB.
struct AntigravityGeneration: Sendable {
    var timestamp: Date?
    var model: String?
    var sizeBytes: Int
}

/// Reads Antigravity's local conversation DBs (see docs/providers/antigravity.md).
/// Quota is not exposed locally, so this provider reports activity stats only.
enum AntigravityScanner {
    static var dataRoot: URL? {
        let gemini = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".gemini")
        let candidates = ["antigravity", "antigravity-ide"].map { gemini.appending(path: $0) }
        let existing = candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
        // Prefer the most recently modified root; ignore backups entirely.
        return existing.max { a, b in
            let ma = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let mb = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return ma < mb
        }
    }

    /// Sessions modified within `days`, each with its generations.
    static func recentSessions(withinDays days: Int = 92) -> [[AntigravityGeneration]] {
        guard let root = dataRoot else { return [] }
        let conversations = root.appending(path: "conversations")
        let cutoff = Date.now.addingTimeInterval(-Double(days) * 86400)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: conversations, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }
        return files.compactMap { url -> (URL, Date)? in
                guard url.pathExtension == "db",
                      let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                        .contentModificationDate,
                      modified > cutoff else { return nil }
                return (url, modified)
            }
            .map { generations(inDB: $0.0, fallbackDate: $0.1) }
            .filter { !$0.isEmpty }
    }

    /// Read gen_metadata rows read-only (immutable — the IDE may hold the WAL).
    static func generations(inDB url: URL, fallbackDate: Date? = nil) -> [AntigravityGeneration] {
        var db: OpaquePointer?
        let uri = "file:\(url.path)?immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK,
              let db else {
            return []
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT data, size FROM gen_metadata", -1, &stmt, nil) == SQLITE_OK,
              let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }

        var result: [AntigravityGeneration] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var blob = Data()
            if let bytes = sqlite3_column_blob(stmt, 0) {
                blob = Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0)))
            }
            let size = Int(sqlite3_column_int64(stmt, 1))
            result.append(parseGeneration(blob: blob, size: size, fallbackDate: fallbackDate))
        }
        return result
    }

    /// Byte-scan the protobuf blob for the two ASCII signals we need — resilient to
    /// schema drift, degrades to counts-only when absent.
    static func parseGeneration(blob: Data, size: Int,
                                fallbackDate: Date? = nil) -> AntigravityGeneration {
        let text = String(decoding: blob, as: UTF8.self)
        var timestamp = fallbackDate
        if let match = text.firstMatch(of: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z/) {
            timestamp = ClaudeTranscriptParser.date(from: String(match.0))
        }
        let model = modelName(in: text)
        return AntigravityGeneration(
            timestamp: timestamp, model: model,
            sizeBytes: size > 0 ? size : blob.count)
    }

    /// Match actual model-shaped identifiers, not arbitrary app names such as
    /// "Claude Switcher.app" or model names quoted inside conversation text. A
    /// provider name is accepted only when it follows an explicit model-field marker.
    static func modelName(in text: String) -> String? {
        let raw: String?
        if let match = text.firstMatch(
            of: /(?:model|model_name|modelName)[^A-Za-z0-9]{0,12}(Gemini[ -](?:\d|Pro|Flash)[A-Za-z0-9 .()_\-]{0,40})/) {
            raw = String(match.1)
        } else if let match = text.firstMatch(
            of: /(?:model|model_name|modelName)[^A-Za-z0-9]{0,12}(Claude[ -](?:\d|Opus|Sonnet|Haiku|Fable|Mythos)[A-Za-z0-9 .()_\-]{0,40})/) {
            raw = String(match.1)
        } else if let match = text.firstMatch(
            of: /(?:model|model_name|modelName)[^A-Za-z0-9]{0,12}(GPT[ -]?\d[A-Za-z0-9 .()_\-]{0,40})/) {
            raw = String(match.1)
        } else {
            raw = nil
        }
        guard var name = raw else { return nil }
        if let open = name.firstIndex(of: "("),
           let close = name[open...].firstIndex(of: ")") {
            name = String(name[...close])
        }
        for marker in [" created_at", " timestamp", " model_name", " model ", " to ", ". "] {
            if let range = name.range(of: marker) {
                name = String(name[..<range.lowerBound])
            }
        }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = name.last, [".", ",", ";", "-", "_"].contains(String(last)) {
            name.removeLast()
        }
        return name.isEmpty || name.count > 48 ? nil : name
    }
}

public struct AntigravityProvider: UsageProvider {
    public static let id = ProviderID.antigravity
    public let displayName = "Antigravity"

    public init() {}

    public func detectInstallation() async -> Bool {
        AntigravityScanner.dataRoot != nil
            || FileManager.default.fileExists(atPath: "/Applications/Antigravity.app")
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        let sessions = AntigravityScanner.recentSessions()
        guard !sessions.isEmpty else {
            throw ProviderError.unsupported(
                reason: "No recent Antigravity activity found (quota isn't stored locally).")
        }
        let now = Date.now
        let startOfToday = Calendar.current.startOfDay(for: now)
        let weekStart = now.addingTimeInterval(-7 * 86400)

        var turnsToday = 0, turnsWeek = 0, bytesToday = 0, bytesWeek = 0
        var sessionsToday = 0
        var lastActivity: Date?
        var models: Set<String> = []
        var modelStats: [String: (turns: Int, tokens: Int)] = [:]
        var dailyPoints: [(Date, Int, Double, String)] = []

        for generations in sessions {
            var sessionActiveToday = false
            for gen in generations {
                if let model = gen.model { models.insert(model) }
                guard let ts = gen.timestamp else { continue }
                let estimatedTokens = max(1, gen.sizeBytes / 4)
                let model = gen.model ?? "Unidentified"
                dailyPoints.append((ts, estimatedTokens, 0, model))
                if ts >= weekStart {
                    turnsWeek += 1
                    bytesWeek += gen.sizeBytes
                    var stat = modelStats[model] ?? (0, 0)
                    stat.turns += 1
                    stat.tokens += estimatedTokens
                    modelStats[model] = stat
                }
                if ts >= startOfToday {
                    turnsToday += 1
                    bytesToday += gen.sizeBytes
                    sessionActiveToday = true
                }
                if lastActivity.map({ ts > $0 }) ?? true { lastActivity = ts }
            }
            if sessionActiveToday { sessionsToday += 1 }
        }

        var detail: [DetailLine] = [
            DetailLine(title: "Sessions", value: "\(sessionsToday) today"),
            DetailLine(title: "Turns today", value: "\(turnsToday)"),
            DetailLine(title: "Turns this week", value: "\(turnsWeek)"),
        ]
        if let lastActivity {
            detail.append(DetailLine(title: "Last activity",
                                     value: lastActivity.formatted(.relative(presentation: .named))))
        }
        if !models.isEmpty {
            detail.append(DetailLine(title: "Detected models",
                                     value: models.sorted().joined(separator: ", ")))
        }
        detail.append(DetailLine(
            title: "Limits",
            value: "Antigravity keeps quota server-side; local activity is shown below."))

        var breakdowns: [Breakdown] = []
        let identified = modelStats.filter { $0.key != "Unidentified" }
        if !identified.isEmpty {
            let total = max(1, identified.values.reduce(0) { $0 + $1.tokens })
            breakdowns.append(Breakdown(title: "This week by model", rows: identified
                .sorted { $0.value.tokens > $1.value.tokens }
                .prefix(4).map { name, stat in
                    Breakdown.Row(name: name,
                                  valueText: "\(stat.turns) turns · ~\(Format.tokens(stat.tokens))",
                                  fraction: Double(stat.tokens) / Double(total))
                }))
        }

        return UsageSnapshot(
            providerID: .antigravity,
            fetchedAt: now,
            accountLabel: "Gemini",
            windows: [],  // quota is server-side only; nothing to show
            tokens: TokenTotals(
                todayTokens: bytesToday / 4,  // ~4 bytes/token heuristic
                weekTokens: bytesWeek / 4,
                costIsEstimated: true),
            detail: detail,
            breakdowns: breakdowns,
            daily: DayStat.aggregate(points: dailyPoints, days: 92, estimated: true)
        )
    }
}

import Foundation
import SQLite3
import BurnBarCore

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
    static func recentSessions(withinDays days: Int = 8) -> [[AntigravityGeneration]] {
        guard let root = dataRoot else { return [] }
        let conversations = root.appending(path: "conversations")
        let cutoff = Date.now.addingTimeInterval(-Double(days) * 86400)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: conversations, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "db" }
            .filter {
                ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast) > cutoff
            }
            .map { generations(inDB: $0) }
            .filter { !$0.isEmpty }
    }

    /// Read gen_metadata rows read-only (immutable — the IDE may hold the WAL).
    static func generations(inDB url: URL) -> [AntigravityGeneration] {
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
            result.append(parseGeneration(blob: blob, size: size))
        }
        return result
    }

    /// Byte-scan the protobuf blob for the two ASCII signals we need — resilient to
    /// schema drift, degrades to counts-only when absent.
    static func parseGeneration(blob: Data, size: Int) -> AntigravityGeneration {
        let text = String(decoding: blob, as: UTF8.self)
        var timestamp: Date?
        if let match = text.firstMatch(of: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z/) {
            timestamp = ClaudeTranscriptParser.date(from: String(match.0))
        }
        var model: String?
        if let match = text.firstMatch(of: /(?:Gemini|Claude|GPT)[ \w.()\-]{0,40}/) {
            model = String(match.0).trimmingCharacters(in: .whitespaces)
        }
        return AntigravityGeneration(
            timestamp: timestamp, model: model,
            sizeBytes: size > 0 ? size : blob.count)
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

        for generations in sessions {
            var sessionActiveToday = false
            for gen in generations {
                if let model = gen.model { models.insert(model) }
                guard let ts = gen.timestamp else { continue }
                if ts >= weekStart {
                    turnsWeek += 1
                    bytesWeek += gen.sizeBytes
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
            DetailLine(title: "Sessions today", value: "\(sessionsToday)"),
            DetailLine(title: "Turns", value: "\(turnsToday) today · \(turnsWeek) this week"),
        ]
        if let lastActivity {
            detail.append(DetailLine(title: "Last activity",
                                     value: lastActivity.formatted(.relative(presentation: .named))))
        }
        if !models.isEmpty {
            detail.append(DetailLine(title: "Models", value: models.sorted().joined(separator: ", ")))
        }
        detail.append(DetailLine(title: "Limits", value: "Not exposed locally by Antigravity"))

        return UsageSnapshot(
            providerID: .antigravity,
            fetchedAt: now,
            accountLabel: "Gemini",
            windows: [],  // quota is server-side only; nothing to show
            tokens: TokenTotals(
                todayTokens: bytesToday / 4,  // ~4 bytes/token heuristic
                weekTokens: bytesWeek / 4,
                costIsEstimated: true),
            detail: detail
        )
    }
}

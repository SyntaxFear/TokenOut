import Testing
import Foundation
import SQLite3
@testable import BurnBarProviders
import BurnBarCore

/// Builds a minimal conversation DB matching the real gen_metadata schema.
private func makeFixtureDB(at url: URL, rows: [(blobText: String, size: Int)]) throws {
    var db: OpaquePointer?
    #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    sqlite3_exec(db, "CREATE TABLE gen_metadata (idx INTEGER, data BLOB, size INTEGER)", nil, nil, nil)
    for (i, row) in rows.enumerated() {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO gen_metadata VALUES (?, ?, ?)", -1, &stmt, nil)
        sqlite3_bind_int(stmt, 1, Int32(i))
        let blob = [UInt8]([0x0A, 0x12]) + Array(row.blobText.utf8) + [0x00, 0xFF]
        _ = blob.withUnsafeBytes {
            sqlite3_bind_blob(stmt, 2, $0.baseAddress, Int32(blob.count), nil)
        }
        sqlite3_bind_int64(stmt, 3, Int64(row.size))
        #expect(sqlite3_step(stmt) == SQLITE_DONE)
        sqlite3_finalize(stmt)
    }
}

@Test func antigravityDBParsing() throws {
    let dir = FileManager.default.temporaryDirectory
        .appending(path: "burnbar-ag-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let dbURL = dir.appending(path: "test.db")

    try makeFixtureDB(at: dbURL, rows: [
        ("model Gemini 3.5 Flash (Low) created_at 2026-07-17T09:15:00Z", 4000),
        ("no signals here", 800),
    ])

    let gens = AntigravityScanner.generations(inDB: dbURL)
    #expect(gens.count == 2)
    #expect(gens[0].model?.hasPrefix("Gemini 3.5 Flash (Low)") == true)
    #expect((gens[0].model?.count ?? 0) <= 47)  // regex match is bounded
    #expect(gens[0].timestamp != nil)
    #expect(gens[0].sizeBytes == 4000)
    #expect(gens[1].timestamp == nil)
    #expect(gens[1].model == nil)
}

@Test func antigravityBlobParsingTolerant() {
    let gen = AntigravityScanner.parseGeneration(blob: Data([0x00, 0x01, 0xFF]), size: 0)
    #expect(gen.timestamp == nil)
    #expect(gen.model == nil)
    #expect(gen.sizeBytes == 3)
}

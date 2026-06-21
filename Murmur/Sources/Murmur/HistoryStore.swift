import Foundation
import SQLite3

/// One recorded dictation. `cleaned` is nil when cleanup was skipped (the pasted
/// text was the raw transcript). Data is local only — it never leaves the machine.
struct HistoryEntry: Identifiable, Equatable, Sendable {
    let id: Int64
    let timestamp: Date
    let raw: String
    let cleaned: String?
    let targetApp: String
    let mode: CleanMode

    /// `true` if the entry matches a search query across raw and cleaned text.
    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        return raw.lowercased().contains(q) || (cleaned?.lowercased().contains(q) ?? false)
    }
}

/// SQLite-backed dictation history. `entries` is the full list newest-first and
/// observable for the UI; every mutation reloads it. If the database fails to
/// open, the store degrades to a no-op so dictation keeps working.
@MainActor
@Observable
final class HistoryStore {
    static let shared = HistoryStore()

    private(set) var entries: [HistoryEntry] = []
    private var db: OpaquePointer?

    init(path: String = HistoryStore.defaultPath) {
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            NSLog("Murmur: failed to open history db at \(path)")
            db = nil
            return
        }
        sqlite3_exec(db, """
            CREATE TABLE IF NOT EXISTS dictations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts REAL NOT NULL,
                raw TEXT NOT NULL,
                cleaned TEXT,
                app TEXT NOT NULL,
                mode TEXT NOT NULL
            );
            """, nil, nil, nil)
        reload()
    }

    /// Append a dictation, then enforce retention. Retention "off" records
    /// nothing; "forever" never prunes; 7d/30d prune older rows on every write.
    func record(raw: String, cleaned: String?, targetApp: String, mode: CleanMode,
                retention: HistoryRetention, now: Date = Date()) {
        guard retention.days != 0, let db else { return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db,
            "INSERT INTO dictations (ts, raw, cleaned, app, mode) VALUES (?,?,?,?,?);",
            -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_double(stmt, 1, now.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 2, raw, -1, Self.transient)
        if let cleaned { sqlite3_bind_text(stmt, 3, cleaned, -1, Self.transient) }
        else { sqlite3_bind_null(stmt, 3) }
        sqlite3_bind_text(stmt, 4, targetApp, -1, Self.transient)
        sqlite3_bind_text(stmt, 5, mode.rawValue, -1, Self.transient)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        prune(retention: retention, now: now)
        reload()
    }

    /// Delete rows older than the retention window. No-op for "off" and "forever".
    func prune(retention: HistoryRetention, now: Date = Date()) {
        guard let days = retention.days, days > 0, let db else { return }
        let cutoff = now.timeIntervalSince1970 - Double(days) * 86_400
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "DELETE FROM dictations WHERE ts < ?;",
                                 -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_double(stmt, 1, cutoff)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        reload()
    }

    func delete(_ id: Int64) {
        guard let db else { return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "DELETE FROM dictations WHERE id = ?;",
                                 -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        reload()
    }

    func clearAll() {
        guard let db else { return }
        sqlite3_exec(db, "DELETE FROM dictations;", nil, nil, nil)
        reload()
    }

    private func reload() {
        guard let db else { entries = []; return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db,
            "SELECT id, ts, raw, cleaned, app, mode FROM dictations ORDER BY ts DESC, id DESC;",
            -1, &stmt, nil) == SQLITE_OK else { return }
        var rows: [HistoryEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(HistoryEntry(
                id: sqlite3_column_int64(stmt, 0),
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                raw: Self.text(stmt, 2) ?? "",
                cleaned: Self.text(stmt, 3),
                targetApp: Self.text(stmt, 4) ?? "",
                mode: Self.text(stmt, 5).flatMap(CleanMode.init) ?? .general))
        }
        sqlite3_finalize(stmt)
        entries = rows
    }

    private static func text(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
        sqlite3_column_text(stmt, col).map { String(cString: $0) }
    }

    /// Tells SQLite to copy bound strings rather than borrow Swift's transient buffers.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    static var defaultPath: String {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Murmur", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.sqlite").path
    }
}

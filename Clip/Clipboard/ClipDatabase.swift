import Foundation
import SQLite3

final class ClipDatabase {
    private var db: OpaquePointer?
    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &db, flags, nil) != SQLITE_OK {
            throw DatabaseError.openFailed(message)
        }
        try exec("""
        CREATE TABLE IF NOT EXISTS clips (
            id TEXT PRIMARY KEY,
            created_at REAL NOT NULL,
            kind TEXT NOT NULL,
            plain_text TEXT,
            rtf_path TEXT,
            image_path TEXT,
            file_urls TEXT,
            color_hex TEXT,
            source_bundle_id TEXT,
            source_app_name TEXT,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            content_hash TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_clips_created ON clips(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_clips_hash ON clips(content_hash);
        """)
    }

    deinit {
        sqlite3_close(db)
    }

    func fetchAll() throws -> [ClipItem] {
        let sql = "SELECT id, created_at, kind, plain_text, rtf_path, image_path, file_urls, color_hex, source_bundle_id, source_app_name, is_pinned, content_hash FROM clips ORDER BY is_pinned DESC, created_at DESC"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var items: [ClipItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            items.append(row(stmt))
        }
        return items
    }

    func upsert(_ item: ClipItem) throws {
        try exec("DELETE FROM clips WHERE content_hash = ? AND id != ?", bind: { stmt in
            self.bind(stmt, 1, item.contentHash)
            self.bind(stmt, 2, item.id.uuidString)
        })
        let sql = """
        INSERT INTO clips (id, created_at, kind, plain_text, rtf_path, image_path, file_urls, color_hex, source_bundle_id, source_app_name, is_pinned, content_hash)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            created_at = excluded.created_at,
            kind = excluded.kind,
            plain_text = excluded.plain_text,
            rtf_path = excluded.rtf_path,
            image_path = excluded.image_path,
            file_urls = excluded.file_urls,
            color_hex = excluded.color_hex,
            source_bundle_id = excluded.source_bundle_id,
            source_app_name = excluded.source_app_name,
            is_pinned = excluded.is_pinned,
            content_hash = excluded.content_hash
        """
        try exec(sql, bind: { stmt in
            self.bind(stmt, 1, item.id.uuidString)
            sqlite3_bind_double(stmt, 2, item.createdAt.timeIntervalSince1970)
            self.bind(stmt, 3, item.kind.rawValue)
            self.bind(stmt, 4, item.plainText)
            self.bind(stmt, 5, item.rtfPath)
            self.bind(stmt, 6, item.imagePath)
            let files = try? JSONEncoder().encode(item.fileURLs.map(\.absoluteString))
            self.bind(stmt, 7, files.flatMap { String(data: $0, encoding: .utf8) })
            self.bind(stmt, 8, item.colorHex)
            self.bind(stmt, 9, item.sourceBundleID)
            self.bind(stmt, 10, item.sourceAppName)
            sqlite3_bind_int(stmt, 11, item.isPinned ? 1 : 0)
            self.bind(stmt, 12, item.contentHash)
        })
    }

    func delete(id: UUID) throws {
        try exec("DELETE FROM clips WHERE id = ?", bind: { stmt in
            self.bind(stmt, 1, id.uuidString)
        })
    }

    func deleteUnpinned() throws {
        try exec("DELETE FROM clips WHERE is_pinned = 0")
    }

    func trim(limit: Int) throws -> [ClipItem] {
        guard limit > 0 else { return [] }
        let sql = """
        SELECT id, created_at, kind, plain_text, rtf_path, image_path, file_urls, color_hex, source_bundle_id, source_app_name, is_pinned, content_hash
        FROM clips
        WHERE is_pinned = 0
        ORDER BY created_at DESC
        LIMIT -1 OFFSET ?
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))
        var extras: [ClipItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            extras.append(row(stmt))
        }
        for item in extras {
            try delete(id: item.id)
        }
        return extras
    }

    func rewritePathPrefix(from oldPrefix: String, to newPrefix: String) throws {
        try exec(
            "UPDATE clips SET image_path = REPLACE(image_path, ?, ?) WHERE image_path IS NOT NULL",
            bind: { stmt in
                self.bind(stmt, 1, oldPrefix)
                self.bind(stmt, 2, newPrefix)
            }
        )
        try exec(
            "UPDATE clips SET rtf_path = REPLACE(rtf_path, ?, ?) WHERE rtf_path IS NOT NULL",
            bind: { stmt in
                self.bind(stmt, 1, oldPrefix)
                self.bind(stmt, 2, newPrefix)
            }
        )
    }

    func item(withHash hash: String) throws -> ClipItem? {
        let sql = "SELECT id, created_at, kind, plain_text, rtf_path, image_path, file_urls, color_hex, source_bundle_id, source_app_name, is_pinned, content_hash FROM clips WHERE content_hash = ? LIMIT 1"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, hash)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return row(stmt)
        }
        return nil
    }

    private func row(_ stmt: OpaquePointer?) -> ClipItem {
        let id = UUID(uuidString: string(stmt, 0) ?? "") ?? UUID()
        let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
        let kind = ClipItem.Kind(rawValue: string(stmt, 2) ?? "text") ?? .text
        let filesJSON = string(stmt, 6)
        let urls: [URL] = {
            guard let filesJSON, let data = filesJSON.data(using: .utf8),
                  let strings = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return strings.compactMap(URL.init(string:))
        }()
        return ClipItem(
            id: id,
            createdAt: created,
            kind: kind,
            plainText: string(stmt, 3),
            rtfPath: string(stmt, 4),
            imagePath: string(stmt, 5),
            fileURLs: urls,
            colorHex: string(stmt, 7),
            sourceBundleID: string(stmt, 8),
            sourceAppName: string(stmt, 9),
            isPinned: sqlite3_column_int(stmt, 10) == 1,
            contentHash: string(stmt, 11) ?? ""
        )
    }

    private func exec(_ sql: String, bind: ((OpaquePointer?) throws -> Void)? = nil) throws {
        if let bind {
            let stmt = try prepare(sql)
            defer { sqlite3_finalize(stmt) }
            try bind(stmt)
            if sqlite3_step(stmt) != SQLITE_DONE {
                throw DatabaseError.execFailed(message)
            }
        } else {
            var error: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
                let text = error.map { String(cString: $0) } ?? message
                sqlite3_free(error)
                throw DatabaseError.execFailed(text)
            }
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw DatabaseError.execFailed(message)
        }
        return stmt
    }

    private func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(stmt, index, value, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func string(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cString)
    }

    private var message: String {
        guard let db else { return "no database" }
        return String(cString: sqlite3_errmsg(db))
    }

    enum DatabaseError: Error {
        case openFailed(String)
        case execFailed(String)
    }
}

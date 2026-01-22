import Foundation
import SQLite3

/// SQLite-based storage for notes with automatic directory creation and file bookmark tracking.
/// This is the primary storage mechanism; xattr is used as write-through for Finder visibility.
final class NoteDatabase {
    static let shared = NoteDatabase()
    
    // MARK: - Storage Location (Single Source of Truth)
    
    /// The database file URL - always in ~/Library/Application Support/Notes/
    static var databaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let notesDir = appSupport.appendingPathComponent("Notes", isDirectory: true)
        return notesDir.appendingPathComponent("notes.db")
    }
    
    /// The directory containing the database
    static var storageDirectory: URL {
        databaseURL.deletingLastPathComponent()
    }
    
    // MARK: - Private Properties
    
    private var db: OpaquePointer?
    private let dbPath: String
    private var isInitialized = false
    
    // MARK: - Initialization
    
    private init() {
        self.dbPath = Self.databaseURL.path
        
        do {
            try initializeDatabase()
            isInitialized = true
            print("📂 [NoteDatabase] Database at: \(dbPath)")
        } catch {
            print("❌ [NoteDatabase] Initialization failed: \(error.localizedDescription)")
            print("   Path: \(dbPath)")
            logDirectoryStatus()
        }
    }
    
    deinit {
        close()
    }
    
    // MARK: - Database Setup
    
    /// Initialize database: create directory, open connection, run migrations
    private func initializeDatabase() throws {
        // 1. Ensure directory exists
        try createStorageDirectoryIfNeeded()
        
        // 2. Open database connection
        try openDatabase()
        
        // 3. Create schema (idempotent)
        try createSchema()
    }
    
    /// Create the storage directory if it doesn't exist
    private func createStorageDirectoryIfNeeded() throws {
        let directory = Self.storageDirectory
        var isDir: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                throw NoteDatabaseError.directoryIsFile(directory.path)
            }
            // Directory exists, good
            return
        }
        
        // Create directory with intermediate directories
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("📁 [NoteDatabase] Created directory: \(directory.path)")
        } catch {
            throw NoteDatabaseError.directoryCreationFailed(directory.path, error)
        }
    }
    
    /// Open SQLite database connection
    private func openDatabase() throws {
        let result = sqlite3_open(dbPath, &db)
        
        if result != SQLITE_OK {
            let errorMessage = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw NoteDatabaseError.openFailed(result, errorMessage)
        }
        
        // Enable foreign keys and WAL mode for better performance
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
    }
    
    /// Create database schema (idempotent - safe to call multiple times)
    private func createSchema() throws {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS notes (
                id TEXT PRIMARY KEY,
                file_path TEXT NOT NULL UNIQUE,
                file_bookmark BLOB,
                title TEXT NOT NULL DEFAULT '',
                body TEXT NOT NULL DEFAULT '',
                created_at REAL NOT NULL,
                modified_at REAL NOT NULL
            );
            """
        
        let createIndexSQL = """
            CREATE INDEX IF NOT EXISTS idx_file_path ON notes(file_path);
            """
        
        var errorMessage: UnsafeMutablePointer<CChar>?
        
        // Create table
        var result = sqlite3_exec(db, createTableSQL, nil, nil, &errorMessage)
        if result != SQLITE_OK {
            let error = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw NoteDatabaseError.schemaCreationFailed(result, error)
        }
        
        // Create index
        result = sqlite3_exec(db, createIndexSQL, nil, nil, &errorMessage)
        if result != SQLITE_OK {
            let error = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw NoteDatabaseError.schemaCreationFailed(result, error)
        }
    }
    
    /// Close database connection
    private func close() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }
    
    // MARK: - Public API
    
    /// Check if database is ready for operations
    var isReady: Bool {
        isInitialized && db != nil
    }
    
    /// Save a note to the database (INSERT OR REPLACE for upsert behavior)
    /// - Parameters:
    ///   - note: The note to save
    ///   - url: The file URL to associate with the note
    /// - Returns: true if save succeeded
    @discardableResult
    func saveNote(_ note: Note, for url: URL) -> Bool {
        guard isReady else {
            print("❌ [NoteDatabase] Cannot save - database not initialized")
            return false
        }
        
        print("💾 [NoteDatabase] Saving note for: \(url.lastPathComponent)")
        
        // Create bookmark for tracking file if it moves
        var bookmark: Data?
        do {
            bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            print("   📎 Created bookmark (\(bookmark?.count ?? 0) bytes)")
        } catch {
            // Bookmark creation is optional - continue without it
            print("   ⚠️ Bookmark creation failed: \(error.localizedDescription)")
        }
        
        // Use INSERT OR REPLACE to handle both new inserts and updates
        let sql = """
            INSERT OR REPLACE INTO notes (id, file_path, file_bookmark, title, body, created_at, modified_at)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """
        
        var statement: OpaquePointer?
        
        defer {
            sqlite3_finalize(statement)
        }
        
        // Prepare statement
        var result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        if result != SQLITE_OK {
            logSQLiteError("Prepare failed", result)
            return false
        }
        
        // Bind parameters
        let id = note.id.uuidString
        let filePath = url.path
        let title = note.title
        let body = note.body
        let createdAt = note.createdAt.timeIntervalSinceReferenceDate
        let modifiedAt = note.modifiedAt.timeIntervalSinceReferenceDate
        
        sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, filePath, -1, SQLITE_TRANSIENT)
        
        if let bookmarkData = bookmark {
            _ = bookmarkData.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, 3, bytes.baseAddress, Int32(bookmarkData.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 3)
        }
        
        sqlite3_bind_text(statement, 4, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, body, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 6, createdAt)
        sqlite3_bind_double(statement, 7, modifiedAt)
        
        // Execute
        result = sqlite3_step(statement)
        
        if result == SQLITE_DONE {
            print("   ✅ Note saved successfully")
            return true
        } else {
            logSQLiteError("Insert failed", result)
            return false
        }
    }
    
    /// Get a note by file URL
    /// - Parameter url: The file URL to look up
    /// - Returns: The note if found, nil otherwise
    func getNote(for url: URL) -> Note? {
        guard isReady else {
            return nil
        }
        
        print("🔍 [NoteDatabase] Looking up note for: \(url.lastPathComponent)")
        
        // First try by current path
        if let note = getNoteByPath(url.path) {
            print("   ✅ Found by current path")
            return note
        }
        
        // TODO: Try resolving bookmarks for moved files
        // This would iterate all notes with bookmarks and try to resolve them
        
        print("   ❌ No note found in database")
        return nil
    }
    
    /// Get a note by file path
    private func getNoteByPath(_ path: String) -> Note? {
        let sql = "SELECT id, file_path, title, body, created_at, modified_at FROM notes WHERE file_path = ?;"
        
        var statement: OpaquePointer?
        
        defer {
            sqlite3_finalize(statement)
        }
        
        var result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        if result != SQLITE_OK {
            return nil
        }
        
        sqlite3_bind_text(statement, 1, path, -1, SQLITE_TRANSIENT)
        
        result = sqlite3_step(statement)
        
        if result == SQLITE_ROW {
            return noteFromRow(statement, filePath: path)
        }
        
        return nil
    }
    
    /// Check if a note exists for the given URL
    func hasNote(for url: URL) -> Bool {
        guard isReady else { return false }
        
        let sql = "SELECT 1 FROM notes WHERE file_path = ? LIMIT 1;"
        var statement: OpaquePointer?
        
        defer {
            sqlite3_finalize(statement)
        }
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            return false
        }
        
        sqlite3_bind_text(statement, 1, url.path, -1, SQLITE_TRANSIENT)
        
        return sqlite3_step(statement) == SQLITE_ROW
    }
    
    /// Delete a note by file URL
    /// - Parameter url: The file URL
    /// - Returns: true if deletion succeeded (or note didn't exist)
    @discardableResult
    func deleteNote(for url: URL) -> Bool {
        guard isReady else { return false }
        
        print("🗑️ [NoteDatabase] Deleting note for: \(url.lastPathComponent)")
        
        let sql = "DELETE FROM notes WHERE file_path = ?;"
        var statement: OpaquePointer?
        
        defer {
            sqlite3_finalize(statement)
        }
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            logSQLiteError("Delete prepare failed", sqlite3_errcode(db))
            return false
        }
        
        sqlite3_bind_text(statement, 1, url.path, -1, SQLITE_TRANSIENT)
        
        let result = sqlite3_step(statement)
        
        if result == SQLITE_DONE {
            let changes = sqlite3_changes(db)
            if changes > 0 {
                print("   ✅ Deleted \(changes) note(s)")
            } else {
                print("   ℹ️ No note existed at that path")
            }
            return true
        } else {
            logSQLiteError("Delete failed", result)
            return false
        }
    }
    
    /// Update file path when a file is moved/renamed
    /// - Parameters:
    ///   - oldURL: The old file URL
    ///   - newURL: The new file URL
    /// - Returns: true if update succeeded
    @discardableResult
    func updateFilePath(from oldURL: URL, to newURL: URL) -> Bool {
        guard isReady else { return false }
        
        let sql = "UPDATE notes SET file_path = ?, modified_at = ? WHERE file_path = ?;"
        var statement: OpaquePointer?
        
        defer {
            sqlite3_finalize(statement)
        }
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            return false
        }
        
        sqlite3_bind_text(statement, 1, newURL.path, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 2, Date().timeIntervalSinceReferenceDate)
        sqlite3_bind_text(statement, 3, oldURL.path, -1, SQLITE_TRANSIENT)
        
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    // MARK: - Private Helpers
    
    /// Create a Note from a SQLite row
    private func noteFromRow(_ statement: OpaquePointer?, filePath: String) -> Note? {
        guard let statement = statement else { return nil }
        
        guard let idCString = sqlite3_column_text(statement, 0),
              let titleCString = sqlite3_column_text(statement, 2),
              let bodyCString = sqlite3_column_text(statement, 3) else {
            return nil
        }
        
        let idString = String(cString: idCString)
        let title = String(cString: titleCString)
        let body = String(cString: bodyCString)
        // Note: createdAt and modifiedAt are read but not used since Note generates new dates
        // We read them to validate the row structure
        _ = sqlite3_column_double(statement, 4) // createdAt
        _ = sqlite3_column_double(statement, 5) // modifiedAt
        
        // Validate UUID format
        guard UUID(uuidString: idString) != nil else { return nil }
        
        // Note: The Note will get a new UUID since Note uses let for id
        // This is fine for display purposes
        return Note(filePath: filePath, title: title, body: body)
    }
    
    /// Log SQLite error with details
    private func logSQLiteError(_ context: String, _ code: Int32) {
        let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown"
        print("   ❌ \(context): SQLite error \(code) - \(message)")
        print("   📂 DB path: \(dbPath)")
        logDirectoryStatus()
    }
    
    /// Log directory existence and writability
    private func logDirectoryStatus() {
        let fm = FileManager.default
        let dir = Self.storageDirectory.path
        
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: dir, isDirectory: &isDir)
        let writable = fm.isWritableFile(atPath: dir)
        
        print("   📁 Directory exists: \(exists), isDir: \(isDir.boolValue), writable: \(writable)")
    }
}

// MARK: - SQLite Transient Constant

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Error Types

enum NoteDatabaseError: LocalizedError {
    case directoryIsFile(String)
    case directoryCreationFailed(String, Error)
    case openFailed(Int32, String)
    case schemaCreationFailed(Int32, String)
    
    var errorDescription: String? {
        switch self {
        case .directoryIsFile(let path):
            return "Storage path exists but is a file, not a directory: \(path)"
        case .directoryCreationFailed(let path, let underlying):
            return "Failed to create storage directory at \(path): \(underlying.localizedDescription)"
        case .openFailed(let code, let message):
            return "Failed to open database (SQLite error \(code)): \(message)"
        case .schemaCreationFailed(let code, let message):
            return "Failed to create database schema (SQLite error \(code)): \(message)"
        }
    }
}

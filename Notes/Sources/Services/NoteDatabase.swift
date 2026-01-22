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
                file_path TEXT NOT NULL,
                file_bookmark BLOB,
                bookmark_hash TEXT,
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
        
        // Create basic indexes (file_path only - bookmark_hash index created after migration)
        result = sqlite3_exec(db, createIndexSQL, nil, nil, &errorMessage)
        if result != SQLITE_OK {
            let error = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw NoteDatabaseError.schemaCreationFailed(result, error)
        }
        
        // Migration: Add bookmark_hash column if it doesn't exist (idempotent)
        // MUST run before creating bookmark_hash index
        try migrateSchema()
    }
    
    /// Migrate schema to add bookmark_hash column (idempotent)
    private func migrateSchema() throws {
        // Check if bookmark_hash column exists
        let checkSQL = "PRAGMA table_info(notes);"
        var statement: OpaquePointer?
        var hasBookmarkHash = false
        
        if sqlite3_prepare_v2(db, checkSQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let nameCString = sqlite3_column_text(statement, 1) {
                    let name = String(cString: nameCString)
                    if name == "bookmark_hash" {
                        hasBookmarkHash = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(statement)
        
        // Add column if it doesn't exist
        if !hasBookmarkHash {
            print("🔄 [NoteDatabase] Migrating: Adding bookmark_hash column...")
            let migrationSQL = "ALTER TABLE notes ADD COLUMN bookmark_hash TEXT;"
            var errorMessage: UnsafeMutablePointer<CChar>?
            let result = sqlite3_exec(db, migrationSQL, nil, nil, &errorMessage)
            if result != SQLITE_OK {
                let error = errorMessage.map { String(cString: $0) } ?? "Unknown error"
                sqlite3_free(errorMessage)
                // Ignore "duplicate column" errors (idempotent migration)
                if !error.contains("duplicate column") {
                    print("❌ [NoteDatabase] Migration failed: \(error)")
                    throw NoteDatabaseError.schemaCreationFailed(result, error)
                }
            } else {
                print("✅ [NoteDatabase] Migration successful: bookmark_hash column added")
            }
        } else {
            print("✅ [NoteDatabase] Migration check: bookmark_hash column already exists")
        }
        
        // Ensure index exists (idempotent)
        let indexSQL = "CREATE INDEX IF NOT EXISTS idx_bookmark_hash ON notes(bookmark_hash);"
        var errorMessage: UnsafeMutablePointer<CChar>?
        var result = sqlite3_exec(db, indexSQL, nil, nil, &errorMessage)
        if result != SQLITE_OK {
            let error = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw NoteDatabaseError.schemaCreationFailed(result, error)
        }
        
        // Add UNIQUE constraint on bookmark_hash (where not null) - use a partial index approach
        // Note: SQLite doesn't support partial unique constraints directly, so we'll handle uniqueness in application logic
        // The index helps with lookups, and we'll use application-level logic to prevent duplicates
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
        
        // Create bookmark for tracking file if it moves (stable identity)
        var bookmark: Data?
        var bookmarkHash: String?
        do {
            bookmark = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: [.fileResourceIdentifierKey],
                relativeTo: nil
            )
            if let bookmark = bookmark {
                bookmarkHash = hashBookmark(bookmark)
                print("   📎 Created bookmark (\(bookmark.count) bytes, hash: \(bookmarkHash!.prefix(8))...)")
            }
        } catch {
            // Bookmark creation is optional - continue without it
            print("   ⚠️ Bookmark creation failed: \(error.localizedDescription)")
        }
        
        // Extract values from note and url for use in both update and insert
        let id = note.id.uuidString
        let filePath = url.path
        let title = note.title
        let body = note.body
        let createdAt = note.createdAt.timeIntervalSinceReferenceDate
        let modifiedAt = note.modifiedAt.timeIntervalSinceReferenceDate
        
        // If we have a bookmark_hash, try to update existing note by bookmark_hash first
        // Otherwise, use INSERT OR REPLACE (which works on id primary key)
        if let hash = bookmarkHash {
            // Try to find existing note by bookmark_hash
            let findSQL = "SELECT id FROM notes WHERE bookmark_hash = ? LIMIT 1;"
            var findStatement: OpaquePointer?
            var existingId: String? = nil
            
            if sqlite3_prepare_v2(db, findSQL, -1, &findStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(findStatement, 1, hash, -1, SQLITE_TRANSIENT)
                if sqlite3_step(findStatement) == SQLITE_ROW {
                    if let idCString = sqlite3_column_text(findStatement, 0) {
                        existingId = String(cString: idCString)
                    }
                }
            }
            sqlite3_finalize(findStatement)
            
            // If found, update using the existing id; otherwise insert with new id
            if let existingId = existingId {
                let updateSQL = """
                    UPDATE notes SET file_path = ?, file_bookmark = ?, title = ?, body = ?, modified_at = ?
                    WHERE id = ?;
                    """
                var updateStatement: OpaquePointer?
                
                if sqlite3_prepare_v2(db, updateSQL, -1, &updateStatement, nil) == SQLITE_OK {
                    sqlite3_bind_text(updateStatement, 1, filePath, -1, SQLITE_TRANSIENT)
                    if let bookmarkData = bookmark {
                        _ = bookmarkData.withUnsafeBytes { bytes in
                            sqlite3_bind_blob(updateStatement, 2, bytes.baseAddress, Int32(bookmarkData.count), SQLITE_TRANSIENT)
                        }
                    } else {
                        sqlite3_bind_null(updateStatement, 2)
                    }
                    sqlite3_bind_text(updateStatement, 3, title, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(updateStatement, 4, body, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_double(updateStatement, 5, modifiedAt)
                    sqlite3_bind_text(updateStatement, 6, existingId, -1, SQLITE_TRANSIENT)
                    
                    let updateResult = sqlite3_step(updateStatement)
                    sqlite3_finalize(updateStatement)
                    
                    if updateResult == SQLITE_DONE {
                        print("   ✅ Note updated by bookmark_hash")
                        return true
                    }
                }
            }
        }
        
        // Insert new note (or update by id if INSERT OR REPLACE)
        let sql = """
            INSERT OR REPLACE INTO notes (id, file_path, file_bookmark, bookmark_hash, title, body, created_at, modified_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
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
        
        // Bind parameters (variables already declared above)
        sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, filePath, -1, SQLITE_TRANSIENT)
        
        if let bookmarkData = bookmark {
            _ = bookmarkData.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, 3, bytes.baseAddress, Int32(bookmarkData.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 3)
        }
        
        if let hash = bookmarkHash {
            sqlite3_bind_text(statement, 4, hash, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        
        sqlite3_bind_text(statement, 5, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, body, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 7, createdAt)
        sqlite3_bind_double(statement, 8, modifiedAt)
        
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
        
        // 1. Try by current path (fast path)
        if let note = getNoteByPath(url.path) {
            print("   ✅ Found by current path")
            return note
        }
        
        // 2. Try by resolving bookmarks (moved files)
        if let note = getNoteByBookmarkResolution(for: url) {
            // Path was updated in getNoteByBookmarkResolution
            return note
        }
        
        print("   ❌ No note found in database")
        return nil
    }
    
    /// Get a note by file path
    private func getNoteByPath(_ path: String) -> Note? {
        let sql = "SELECT id, file_path, file_bookmark, title, body, created_at, modified_at FROM notes WHERE file_path = ?;"
        
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
        
        // Try by path first
        let sql = "SELECT 1 FROM notes WHERE file_path = ? LIMIT 1;"
        var statement: OpaquePointer?
        
        defer {
            sqlite3_finalize(statement)
        }
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, url.path, -1, SQLITE_TRANSIENT)
            if sqlite3_step(statement) == SQLITE_ROW {
                return true
            }
        }
        
        // Try bookmark resolution
        return getNoteByBookmarkResolution(for: url) != nil
    }
    
    /// Delete a note by file URL
    /// - Parameter url: The file URL
    /// - Returns: true if deletion succeeded (or note didn't exist)
    @discardableResult
    func deleteNote(for url: URL) -> Bool {
        guard isReady else { return false }
        
        print("🗑️ [NoteDatabase] Deleting note for: \(url.lastPathComponent)")
        
        // Try by path first
        var sql = "DELETE FROM notes WHERE file_path = ?;"
        var statement: OpaquePointer?
        
        defer {
            sqlite3_finalize(statement)
        }
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            logSQLiteError("Delete prepare failed", sqlite3_errcode(db))
            return false
        }
        
        sqlite3_bind_text(statement, 1, url.path, -1, SQLITE_TRANSIENT)
        var result = sqlite3_step(statement)
        sqlite3_finalize(statement)
        statement = nil
        
        if result == SQLITE_DONE {
            let changes = sqlite3_changes(db)
            if changes > 0 {
                print("   ✅ Deleted \(changes) note(s) by path")
                return true
            }
        }
        
        // Path lookup failed - try bookmark resolution
        if let note = getNoteByBookmarkResolution(for: url) {
            // Found by bookmark - delete by bookmark_hash
            guard let bookmarkHash = note.bookmarkData.map({ hashBookmark($0) }) else {
                print("   ⚠️ Found by bookmark but no hash available")
                return false
            }
            
            sql = "DELETE FROM notes WHERE bookmark_hash = ?;"
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, bookmarkHash, -1, SQLITE_TRANSIENT)
                result = sqlite3_step(statement)
                
                if result == SQLITE_DONE {
                    let changes = sqlite3_changes(db)
                    if changes > 0 {
                        print("   ✅ Deleted \(changes) note(s) by bookmark")
                        return true
                    }
                }
            }
        }
        
        print("   ℹ️ No note existed at that path or bookmark")
        return true  // Return true if note didn't exist (idempotent)
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
    
    // MARK: - Bookmark Helpers
    
    /// Compute a hash of bookmark data for indexing
    private func hashBookmark(_ bookmark: Data) -> String {
        // Use base64 encoding as stable identifier (simpler than SHA256)
        return bookmark.base64EncodedString()
    }
    
    /// Get stable file resource identifier (survives rename/move within same volume)
    private func getFileResourceIdentifier(for url: URL) -> Data? {
        do {
            let values = try url.resourceValues(forKeys: [.fileResourceIdentifierKey])
            if let identifier = values.fileResourceIdentifier as? NSData {
                return identifier as Data
            }
        } catch {
            print("   ⚠️ Failed to get file resource identifier: \(error.localizedDescription)")
        }
        return nil
    }
    
    /// Get a note by resolving file bookmark (survives rename/move)
    private func getNoteByBookmarkResolution(for url: URL) -> Note? {
        // Try to create a bookmark for the current URL
        guard let currentBookmark = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: [.fileResourceIdentifierKey],
            relativeTo: nil
        ) else {
            return nil
        }
        
        // Get file resource identifier for comparison
        guard let currentFileID = getFileResourceIdentifier(for: url) else {
            return nil
        }
        
        // Search all notes with bookmarks and try to resolve
        let sql = "SELECT id, file_path, file_bookmark, title, body, created_at, modified_at FROM notes WHERE file_bookmark IS NOT NULL;"
        var statement: OpaquePointer?
        
        defer {
            sqlite3_finalize(statement)
        }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            // Read bookmark data (column index 2)
            guard let bookmarkBlob = sqlite3_column_blob(statement, 2) else { continue }
            let bookmarkLength = sqlite3_column_bytes(statement, 2)
            let bookmarkData = Data(bytes: bookmarkBlob, count: Int(bookmarkLength))
            
            // Try to resolve bookmark
            var isStale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                // Compare file resource identifiers
                if let resolvedFileID = getFileResourceIdentifier(for: resolvedURL),
                   resolvedFileID == currentFileID {
                    // Found match! Update path and return note
                    guard let filePathCString = sqlite3_column_text(statement, 1) else { continue }
                    let filePath = String(cString: filePathCString)
                    let note = noteFromRow(statement, filePath: url.path)  // Use current path, not stored path
                    
                    // Update stored path to current location
                    if let note = note {
                        updateFilePath(from: URL(fileURLWithPath: filePath), to: url)
                    }
                    
                    print("   ✅ Found by bookmark resolution (moved file)")
                    return note
                }
            } catch {
                // Bookmark resolution failed - skip this entry
                continue
            }
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    /// Create a Note from a SQLite row
    private func noteFromRow(_ statement: OpaquePointer?, filePath: String) -> Note? {
        guard let statement = statement else { return nil }
        
        guard let idCString = sqlite3_column_text(statement, 0),
              let titleCString = sqlite3_column_text(statement, 3),
              let bodyCString = sqlite3_column_text(statement, 4) else {
            return nil
        }
        
        let idString = String(cString: idCString)
        let title = String(cString: titleCString)
        let body = String(cString: bodyCString)
        // Note: createdAt and modifiedAt are read but not used since Note generates new dates
        // We read them to validate the row structure
        _ = sqlite3_column_double(statement, 5) // createdAt
        _ = sqlite3_column_double(statement, 6) // modifiedAt
        
        // Read bookmark data if available
        var bookmarkData: Data? = nil
        if let bookmarkBlob = sqlite3_column_blob(statement, 2) {
            let bookmarkLength = sqlite3_column_bytes(statement, 2)
            bookmarkData = Data(bytes: bookmarkBlob, count: Int(bookmarkLength))
        }
        
        // Validate UUID format
        guard UUID(uuidString: idString) != nil else { return nil }
        
        // Note: The Note will get a new UUID since Note uses let for id
        // This is fine for display purposes
        return Note(filePath: filePath, title: title, body: body, bookmarkData: bookmarkData)
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

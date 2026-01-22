import Foundation
import CoreServices

/// Hybrid note storage: NoteDatabase (SQLite) as primary, xattr (Finder Comments) as write-through.
/// 
/// Storage strategy:
/// - Save: Write to database first, then write-through to xattr for Finder visibility
/// - Read: Try database first, fallback to xattr (for legacy data or moved files)
/// - Delete: Remove from both database and xattr
class NoteStorage {
    static let shared = NoteStorage()
    
    private let xattrName = "com.apple.metadata:kMDItemFinderComment"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Check if a file/folder has an associated note
    func hasNote(for url: URL) -> Bool {
        // Try database first
        if NoteDatabase.shared.hasNote(for: url) {
            return true
        }
        
        // Fallback to xattr
        guard let comment = readFinderComment(for: url) else { return false }
        return !comment.isEmpty
    }
    
    /// Get note for a file/folder
    func getNote(for url: URL) -> Note? {
        // Try database first
        if let note = NoteDatabase.shared.getNote(for: url) {
            print("📚 [NoteStorage] Found note in database for: \(url.lastPathComponent)")
            return note
        }
        
        // Fallback to xattr (handles legacy notes and moved files)
        print("📚 [NoteStorage] Checking xattr fallback for: \(url.lastPathComponent)")
        guard let comment = readFinderComment(for: url) else { return nil }
        return Note(fromComment: comment, filePath: url.path)
    }
    
    /// Save a note to a file/folder
    /// Writes to database first, then to xattr for Finder visibility
    /// - Returns: true if at least one storage method succeeded
    @discardableResult
    func saveNote(_ note: Note, to url: URL) -> Bool {
        var dbSuccess = false
        var xattrSuccess = false
        
        // 1. Save to database (primary storage)
        dbSuccess = NoteDatabase.shared.saveNote(note, for: url)
        if !dbSuccess {
            print("⚠️ [NoteStorage] Database save failed for: \(url.lastPathComponent)")
        }
        
        // 2. Write-through to xattr (for Finder visibility)
        xattrSuccess = writeFinderComment(note.encodedComment, to: url)
        if xattrSuccess {
            print("✅ [NoteStorage] Saved note to: \(url.lastPathComponent)")
        } else {
            print("⚠️ [NoteStorage] xattr save failed for: \(url.lastPathComponent)")
        }
        
        // Success if at least one method worked
        return dbSuccess || xattrSuccess
    }
    
    /// Remove note from a file/folder
    /// Removes from both database and xattr
    /// - Returns: true if removal succeeded from both (or note didn't exist)
    @discardableResult
    func removeNote(for url: URL) -> Bool {
        var dbSuccess = true
        var xattrSuccess = true
        
        // 1. Remove from database
        dbSuccess = NoteDatabase.shared.deleteNote(for: url)
        
        // 2. Remove from xattr
        xattrSuccess = clearFinderComment(for: url)
        
        if dbSuccess && xattrSuccess {
            print("✅ [NoteStorage] Removed note from: \(url.lastPathComponent)")
        } else {
            print("⚠️ [NoteStorage] Partial removal for: \(url.lastPathComponent) (db: \(dbSuccess), xattr: \(xattrSuccess))")
        }
        
        return dbSuccess && xattrSuccess
    }
    
    // MARK: - Finder Comment I/O (xattr)
    
    /// Read the Finder Comment from a file's extended attributes
    private func readFinderComment(for url: URL) -> String? {
        print("🔍 [NoteStorage] Reading comment for: \(url.lastPathComponent)")
        print("   Full path: \(url.path)")
        
        let exists = FileManager.default.fileExists(atPath: url.path)
        print("   File exists: \(exists)")
        
        // Try MDItem first (faster for Spotlight-indexed files)
        if let mdItem = MDItemCreateWithURL(nil, url as CFURL) {
            print("   MDItem created: true")
            if let comment = MDItemCopyAttribute(mdItem, kMDItemFinderComment) as? String,
               !comment.isEmpty {
                print("   MDItem comment: found")
                return comment
            } else {
                print("   MDItem comment: (nil)")
            }
        } else {
            print("   MDItem created: false")
        }
        
        // Fallback: Always try xattr directly
        // This handles recently moved files, unindexed locations, etc.
        print("   📂 MDItem failed or empty, trying xattr fallback...")
        return readXattr(for: url)
    }
    
    /// Read xattr directly (fallback method)
    private func readXattr(for url: URL) -> String? {
        let path = url.path
        
        print("   🔧 [xattr] Reading directly for: \(url.lastPathComponent)")
        
        // Get the size of the attribute
        let size = getxattr(path, xattrName, nil, 0, 0, 0)
        print("   🔧 [xattr] Size query result: \(size)")
        
        guard size > 0 else {
            if size == -1 {
                let err = errno
                print("   🔧 [xattr] getxattr size failed: errno=\(err) (\(String(cString: strerror(err))))")
                if err == ENOATTR {
                    print("   🔧 [xattr] No such attribute exists on file")
                }
            }
            print("   ❌ xattr fallback also failed - no note found")
            return nil
        }
        
        // Read the attribute data
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { bytes in
            getxattr(path, xattrName, bytes.baseAddress, size, 0, 0)
        }
        guard result > 0 else {
            print("   ❌ xattr read failed")
            return nil
        }
        
        // Decode from plist format
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let comment = plist as? String else {
            print("   ❌ xattr plist decode failed")
            return nil
        }
        
        print("   ✅ xattr read succeeded")
        return comment
    }
    
    /// Write a Finder Comment to a file's extended attributes
    /// Uses AppleScript for reliability (properly integrates with Spotlight),
    /// falls back to xattr if AppleScript fails
    private func writeFinderComment(_ comment: String, to url: URL) -> Bool {
        // Primary method: Use AppleScript (most reliable for Finder Comment integration)
        if writeViaAppleScript(comment, to: url) {
            return true
        }
        
        // Fallback: Write via xattr directly
        print("⚠️ AppleScript failed, falling back to xattr")
        return writeViaXattr(comment, to: url)
    }
    
    /// Write Finder Comment using AppleScript (integrates properly with Spotlight)
    private func writeViaAppleScript(_ comment: String, to url: URL) -> Bool {
        // Escape special characters for AppleScript string
        let escapedComment = comment
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = """
        tell application "Finder"
            set theFile to POSIX file "\(url.path)" as alias
            set comment of theFile to "\(escapedComment)"
        end tell
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if error == nil {
                return true
            } else {
                print("⚠️ AppleScript error: \(error?[NSAppleScript.errorMessage] ?? "unknown")")
            }
        }
        return false
    }
    
    /// Write Finder Comment via xattr (fallback method)
    private func writeViaXattr(_ comment: String, to url: URL) -> Bool {
        // Encode as binary plist (Finder expects this format)
        guard let plistData = try? PropertyListSerialization.data(
            fromPropertyList: comment,
            format: .binary,
            options: 0
        ) else {
            print("❌ Failed to encode comment as plist")
            return false
        }
        
        let result = plistData.withUnsafeBytes { bytes in
            setxattr(url.path, xattrName, bytes.baseAddress, bytes.count, 0, 0)
        }
        
        if result != 0 {
            let errorCode = errno
            print("❌ setxattr failed with error: \(errorCode) - \(String(cString: strerror(errorCode)))")
            return false
        }
        
        // Touch the file and force Spotlight reindex
        touchFile(url)
        forceSpotlightReindex(url)
        
        return true
    }
    
    /// Force Spotlight to reindex a file (for xattr fallback)
    private func forceSpotlightReindex(_ url: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/mdimport")
        task.arguments = [url.path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }
    
    /// Clear the Finder Comment from a file
    private func clearFinderComment(for url: URL) -> Bool {
        // Primary method: Use AppleScript
        if clearViaAppleScript(for: url) {
            return true
        }
        
        // Fallback: Remove xattr directly
        let result = removexattr(url.path, xattrName, 0)
        
        // Success if removed or attribute didn't exist
        if result == 0 || errno == ENOATTR {
            touchFile(url)
            forceSpotlightReindex(url)
            return true
        }
        
        return false
    }
    
    /// Clear Finder Comment using AppleScript
    private func clearViaAppleScript(for url: URL) -> Bool {
        let script = """
        tell application "Finder"
            set theFile to POSIX file "\(url.path)" as alias
            set comment of theFile to ""
        end tell
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if error == nil {
                return true
            }
        }
        return false
    }
    
    /// Touch the file to trigger Spotlight re-indexing
    private func touchFile(_ url: URL) {
        let now = Date()
        try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
    }
}

// MARK: - Error Types

enum NoteStorageError: LocalizedError {
    case encodingFailed
    case writeFailed(Int32)
    case readFailed
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode note data"
        case .writeFailed(let code):
            return "Failed to write note (error \(code))"
        case .readFailed:
            return "Failed to read note"
        }
    }
}

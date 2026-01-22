import Foundation
import CoreServices

/// Stores notes in Finder Comments (kMDItemFinderComment) extended attribute
class NoteStorage {
    static let shared = NoteStorage()
    
    private let xattrName = "com.apple.metadata:kMDItemFinderComment"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Check if a file/folder has an associated note
    func hasNote(for url: URL) -> Bool {
        guard let comment = readFinderComment(for: url) else { return false }
        return !comment.isEmpty
    }
    
    /// Get note for a file/folder
    func getNote(for url: URL) -> Note? {
        guard let comment = readFinderComment(for: url) else { return nil }
        return Note(fromComment: comment, filePath: url.path)
    }
    
    /// Save a note to a file/folder's Finder Comment
    /// - Returns: true if save succeeded, false otherwise
    @discardableResult
    func saveNote(_ note: Note, to url: URL) -> Bool {
        let success = writeFinderComment(note.encodedComment, to: url)
        if success {
            // Redacted log - only show filename
            print("✅ Saved note to: \(url.lastPathComponent)")
        } else {
            print("❌ Failed to save note to: \(url.lastPathComponent)")
        }
        return success
    }
    
    /// Remove note from a file/folder
    /// - Returns: true if removal succeeded, false otherwise
    @discardableResult
    func removeNote(for url: URL) -> Bool {
        let success = clearFinderComment(for: url)
        if success {
            print("✅ Removed note from: \(url.lastPathComponent)")
        } else {
            print("❌ Failed to remove note from: \(url.lastPathComponent)")
        }
        return success
    }
    
    // MARK: - Finder Comment I/O
    
    /// Read the Finder Comment from a file's extended attributes
    private func readFinderComment(for url: URL) -> String? {
        // Use MDItemCopyAttribute for reading (most reliable for Spotlight-indexed files)
        guard let mdItem = MDItemCreateWithURL(nil, url as CFURL) else {
            return nil
        }
        
        if let comment = MDItemCopyAttribute(mdItem, kMDItemFinderComment) as? String, !comment.isEmpty {
            return comment
        }
        
        // Fallback: try reading xattr directly
        return readXattr(for: url)
    }
    
    /// Read xattr directly (fallback method)
    private func readXattr(for url: URL) -> String? {
        let path = url.path
        
        // Get the size of the attribute
        let size = getxattr(path, xattrName, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        
        // Read the attribute data
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { bytes in
            getxattr(path, xattrName, bytes.baseAddress, size, 0, 0)
        }
        guard result > 0 else { return nil }
        
        // Decode from plist format
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let comment = plist as? String else {
            return nil
        }
        
        return comment
    }
    
    /// Write a Finder Comment to a file's extended attributes
    private func writeFinderComment(_ comment: String, to url: URL) -> Bool {
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
        
        // Touch the file to update Spotlight index
        touchFile(url)
        
        return true
    }
    
    /// Clear the Finder Comment from a file
    private func clearFinderComment(for url: URL) -> Bool {
        let result = removexattr(url.path, xattrName, 0)
        
        // Success if removed or attribute didn't exist
        if result == 0 || errno == ENOATTR {
            touchFile(url)
            return true
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

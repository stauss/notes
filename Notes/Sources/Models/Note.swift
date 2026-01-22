import Foundation

struct Note: Identifiable, Codable {
    let id: UUID
    var filePath: String
    var title: String
    var body: String
    var createdAt: Date
    var modifiedAt: Date
    var bookmarkData: Data?  // Stable identifier for rename/move persistence
    
    // MARK: - Format Constants
    
    private static let formatHeader = "NOTES:v1"
    private static let titleDelimiter = "---TITLE---"
    private static let bodyDelimiter = "---BODY---"
    
    // MARK: - Initializers
    
    init(filePath: String, title: String, body: String, bookmarkData: Data? = nil) {
        self.id = UUID()
        self.filePath = filePath
        self.title = title
        self.body = body
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.bookmarkData = bookmarkData
    }
    
    /// Decode from kMDItemFinderComment string with legacy migration support
    init?(fromComment comment: String, filePath: String) {
        guard !comment.isEmpty else { return nil }
        
        self.id = UUID()
        self.filePath = filePath
        self.createdAt = Date()
        self.modifiedAt = Date()
        
        // Check for our format header
        if comment.hasPrefix(Self.formatHeader) {
            // Parse structured format
            let lines = comment.components(separatedBy: "\n")
            var inTitle = false
            var inBody = false
            var titleLines: [String] = []
            var bodyLines: [String] = []
            
            for line in lines.dropFirst() {  // Skip header
                if line == Self.titleDelimiter {
                    inTitle = true
                    inBody = false
                } else if line == Self.bodyDelimiter {
                    inTitle = false
                    inBody = true
                } else if inTitle {
                    titleLines.append(line)
                } else if inBody {
                    bodyLines.append(line)
                }
            }
            
            self.title = titleLines.joined(separator: "\n")
            self.body = bodyLines.joined(separator: "\n")
        } else {
            // Legacy format: entire comment is body, no title
            self.title = ""
            self.body = comment
        }
    }
    
    // MARK: - Encoding
    
    /// Encode for storage in kMDItemFinderComment
    var encodedComment: String {
        """
        \(Self.formatHeader)
        \(Self.titleDelimiter)
        \(title)
        \(Self.bodyDelimiter)
        \(body)
        """
    }
    
    // MARK: - Computed Properties
    
    var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }
    
    /// Combined content for backward compatibility
    var content: String {
        if title.isEmpty {
            return body
        }
        return "\(title)\n\n\(body)"
    }
    
    var wordCount: Int {
        content.split(whereSeparator: { $0.isWhitespace }).count
    }
    
    var characterCount: Int {
        content.count
    }
    
    /// Check if note has any content
    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Mutations
    
    mutating func update(title: String, body: String) {
        self.title = title
        self.body = body
        self.modifiedAt = Date()
    }
}

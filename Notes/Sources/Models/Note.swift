import Foundation

struct Note: Identifiable, Codable {
    let id: UUID
    var filePath: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    
    init(filePath: String, content: String) {
        self.id = UUID()
        self.filePath = filePath
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    mutating func updateContent(_ newContent: String) {
        self.content = newContent
        self.modifiedAt = Date()
    }
    
    var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }
    
    var wordCount: Int {
        content.split(separator: " ").count
    }
    
    var characterCount: Int {
        content.count
    }
}

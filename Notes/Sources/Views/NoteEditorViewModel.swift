import SwiftUI
import AppKit

class NoteEditorViewModel: ObservableObject {
    @Published var filePath: String
    @Published var noteContent: String
    @Published var isNewNote: Bool
    
    private var originalNote: Note?
    
    var fileName: String {
        if filePath.isEmpty {
            return "No file selected"
        }
        return URL(fileURLWithPath: filePath).lastPathComponent
    }
    
    var isDirectory: Bool {
        if filePath.isEmpty {
            return false
        }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir)
        return isDir.boolValue
    }
    
    var characterCount: Int {
        noteContent.count
    }
    
    var wordCount: Int {
        noteContent.split(separator: " ").count
    }
    
    init(filePath: String, existingNote: Note? = nil) {
        self.filePath = filePath
        self.originalNote = existingNote
        self.noteContent = existingNote?.content ?? ""
        self.isNewNote = existingNote == nil
    }
    
    func saveNote() {
        // Don't save if no file path selected
        guard !filePath.isEmpty else {
            print("❌ Cannot save note: No file path selected")
            return
        }
        
        let note: Note
        
        if let existing = originalNote {
            // Update existing note
            var updatedNote = existing
            updatedNote.updateContent(noteContent)
            note = updatedNote
        } else {
            // Create new note
            note = Note(filePath: filePath, content: noteContent)
        }
        
        NoteStorage.shared.saveNote(note)
        print("Note saved for: \(filePath)")
    }
    
    func showFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a file or folder to attach the note to"
        
        if panel.runModal() == .OK, let url = panel.url {
            self.filePath = url.path
        }
    }
}

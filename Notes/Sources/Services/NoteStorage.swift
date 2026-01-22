import Foundation

class NoteStorage {
    static let shared = NoteStorage()
    
    private var notes: [String: Note] = [:]
    private let storageURL: URL
    
    private init() {
        let settings = AppSettings.load()
        self.storageURL = URL(fileURLWithPath: settings.noteStorageLocation)
        loadNotes()
    }
    
    // MARK: - Public Methods
    
    /// Check if a file/folder has an associated note
    func hasNote(for filePath: String) -> Bool {
        return notes[filePath] != nil
    }
    
    /// Get note for a file/folder
    func getNote(for filePath: String) -> Note? {
        return notes[filePath]
    }
    
    /// Save or update a note for a file/folder
    func saveNote(_ note: Note) {
        notes[note.filePath] = note
        persistNotes()
    }
    
    /// Remove note for a file/folder
    func removeNote(for filePath: String) {
        notes.removeValue(forKey: filePath)
        persistNotes()
    }
    
    /// Get all notes
    func getAllNotes() -> [Note] {
        return Array(notes.values)
    }
    
    // MARK: - Persistence
    
    private func loadNotes() {
        // Create storage directory if it doesn't exist
        try? FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        
        let notesFile = storageURL.appendingPathComponent("notes.json")
        
        guard FileManager.default.fileExists(atPath: notesFile.path),
              let data = try? Data(contentsOf: notesFile),
              let loadedNotes = try? JSONDecoder().decode([String: Note].self, from: data) else {
            return
        }
        
        self.notes = loadedNotes
    }
    
    private func persistNotes() {
        let notesFile = storageURL.appendingPathComponent("notes.json")
        
        guard let data = try? JSONEncoder().encode(notes) else {
            print("Failed to encode notes")
            return
        }
        
        do {
            try data.write(to: notesFile)
        } catch {
            print("Failed to save notes: \(error)")
        }
    }
}

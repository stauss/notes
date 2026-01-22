import SwiftUI
import AppKit
import Combine

class NoteEditorViewModel: ObservableObject {
    @Published var targetURL: URL?
    @Published var title: String
    @Published var body: String
    
    private var originalTitle: String
    private var originalBody: String
    private var existingNote: Note?
    private var cancellables = Set<AnyCancellable>()
    
    /// Callback for auto-save (set by window controller)
    var onAutoSave: ((Note) -> Void)?
    
    // MARK: - Computed Properties
    
    /// Whether the note has been modified from its original state
    var isDirty: Bool {
        title != originalTitle || body != originalBody
    }
    
    /// Whether there's an existing note loaded
    var hasExistingNote: Bool {
        existingNote != nil
    }
    
    /// Whether a target file is selected
    var hasTargetFile: Bool {
        targetURL != nil
    }
    
    /// The filename to display in the UI
    var fileName: String? {
        targetURL?.lastPathComponent
    }
    
    /// Whether the note content is empty
    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Whether the target is a directory
    var isDirectory: Bool {
        guard let url = targetURL else { return false }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }
    
    // MARK: - Initialization
    
    init(targetURL: URL?, existingNote: Note?) {
        self.targetURL = targetURL
        self.existingNote = existingNote
        
        // Initialize title/body from existing note
        let initialTitle = existingNote?.title ?? ""
        let initialBody = existingNote?.body ?? ""
        
        self.title = initialTitle
        self.body = initialBody
        self.originalTitle = initialTitle
        self.originalBody = initialBody
        
        // Setup debounced auto-save (300-500ms after last keystroke)
        setupAutoSave()
    }
    
    // MARK: - Public Methods
    
    /// Build a Note from the current state
    func buildNote() -> Note? {
        guard let url = targetURL else { return nil }
        return Note(
            filePath: url.path,
            title: title,
            body: body
        )
    }
    
    /// Mark the current state as the new "original" (after save)
    func markAsSaved() {
        originalTitle = title
        originalBody = body
    }
    
    /// Open file picker to select a new target
    func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a file or folder to attach the note to"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            // Update target
            self.targetURL = url
            
            // Load existing note for the new target
            if let existingNote = NoteStorage.shared.getNote(for: url) {
                self.title = existingNote.title
                self.body = existingNote.body
                self.existingNote = existingNote
            } else {
                // No existing note - clear fields
                self.title = ""
                self.body = ""
                self.existingNote = nil
            }
            
            // Reset original state
            self.originalTitle = self.title
            self.originalBody = self.body
        }
    }
    
    // MARK: - Auto-Save
    
    /// Setup debounced auto-save pipeline
    private func setupAutoSave() {
        // Combine title and body changes, debounce, then save
        Publishers.CombineLatest($title, $body)
            .dropFirst()  // Skip initial values
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.triggerAutoSave()
            }
            .store(in: &cancellables)
    }
    
    /// Trigger auto-save if note is dirty and not empty
    private func triggerAutoSave() {
        guard let note = buildNote(), !isEmpty, isDirty else { return }
        onAutoSave?(note)
        markAsSaved()
    }
}

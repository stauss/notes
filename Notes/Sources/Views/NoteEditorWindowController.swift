import SwiftUI
import AppKit

class NoteEditorWindowController: NSWindowController {
    private var filePath: String
    private var existingNote: Note?
    
    init(filePath: String, existingNote: Note? = nil) {
        self.filePath = filePath
        self.existingNote = existingNote
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = existingNote == nil ? "Add Note" : "Edit Note"
        window.contentView = NSHostingView(rootView: NoteEditorView(filePath: filePath, existingNote: existingNote))
        window.minSize = NSSize(width: 400, height: 300)
        
        // Make window float above other windows
        window.level = .floating
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?
    var preferencesWindowController: PreferencesWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize menu bar manager
        menuBarManager = MenuBarManager()
        
        // Initialize preferences window controller
        preferencesWindowController = PreferencesWindowController()
        
        // Connect preferences to menu bar manager
        menuBarManager?.preferencesWindowController = preferencesWindowController
        
        // Register global keyboard shortcut
        registerGlobalShortcut()
        
        // Hide from Dock (LSUIElement in Info.plist handles this, but we can also do it programmatically)
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func registerGlobalShortcut() {
        let settings = AppSettings.load()
        
        ShortcutManager.shared.registerShortcut(settings.globalShortcut)
        
        // Set callback for when shortcut is pressed
        ShortcutManager.shared.onShortcutPressed = { [weak self] in
            self?.handleGlobalShortcut()
        }
    }
    
    private func handleGlobalShortcut() {
        // Check if there's a Finder selection
        let selectedURL = FinderSelectionMonitor.shared.getSelectedItem()
        
        if let url = selectedURL {
            // File selected - open editor with that file
            let existingNote = NoteStorage.shared.getNote(for: url.path)
            let editorWindow = NoteEditorWindowController(filePath: url.path, existingNote: existingNote)
            editorWindow.show()
            
            if existingNote != nil {
                showNotification(title: "Note Editor", message: "Editing note for \(url.lastPathComponent)")
            } else {
                showNotification(title: "Note Editor", message: "Adding note for \(url.lastPathComponent)")
            }
        } else {
            // No selection - show editor with file picker
            // Use a temporary path, user will need to browse
            showNotification(title: "Note Editor", message: "No file selected - use Browse button to select a file")
            
            // Open editor with empty path - user can browse
            let editorWindow = NoteEditorWindowController(filePath: "", existingNote: nil)
            editorWindow.show()
        }
    }
    
    private func showNotification(title: String, message: String) {
        // Note: UserNotifications requires a proper app bundle, which SPM builds don't have
        // For now, just log to console. Will work properly when built as .app bundle
        print("📝 \(title): \(message)")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

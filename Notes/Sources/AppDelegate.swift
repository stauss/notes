import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?
    var preferencesWindowController: PreferencesWindowController?
    
    // Retain the editor window to prevent deallocation
    private var currentEditorWindow: NoteEditorWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize database (creates directory and schema if needed)
        _ = NoteDatabase.shared
        
        // Initialize menu bar manager
        menuBarManager = MenuBarManager()
        
        // Initialize preferences window controller
        preferencesWindowController = PreferencesWindowController()
        
        // Connect preferences to menu bar manager
        menuBarManager?.preferencesWindowController = preferencesWindowController
        
        // Register global keyboard shortcut
        registerGlobalShortcut()
        
        // Listen for editor open requests from menu bar
        setupNotificationObservers()
        
        // Hide from Dock (LSUIElement in Info.plist handles this, but we can also do it programmatically)
        NSApp.setActivationPolicy(.accessory)
    }
    
    // MARK: - Global Shortcut
    
    private func registerGlobalShortcut() {
        let settings = AppSettings.load()
        
        ShortcutManager.shared.registerShortcut(settings.globalShortcut)
        
        // Set callback for when shortcut is pressed
        ShortcutManager.shared.onShortcutPressed = { [weak self] in
            self?.handleGlobalShortcut()
        }
    }
    
    private func handleGlobalShortcut() {
        print("⌨️ Global shortcut pressed!")
        
        // TRUE TOGGLE: If panel is visible, close it and return
        if let editor = currentEditorWindow,
           let window = editor.window,
           window.isVisible {
            print("   Panel visible - closing (toggle off)")
            editor.dismiss()  // This triggers handleDismiss() for save/delete
            currentEditorWindow = nil
            return
        }
        
        // Panel not visible - open it
        let selectedURL = FinderSelectionMonitor.shared.getSelectedItem()
        
        guard let url = selectedURL else {
            print("📝 No file selected in Finder - panel not shown")
            return
        }
        
        print("   Opening panel for: \(url.lastPathComponent)")
        
        let existingNote = NoteStorage.shared.getNote(for: url)
        
        currentEditorWindow = NoteEditorWindowController(
            targetURL: url,
            existingNote: existingNote
        )
        currentEditorWindow?.show()
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Listen for requests to open the editor (from menu bar)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenNoteEditorNotification(_:)),
            name: .openNoteEditor,
            object: nil
        )
        
        // Listen for editor dismissal to clean up reference
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEditorDismissed(_:)),
            name: .noteEditorWillDismiss,
            object: nil
        )
    }
    
    @objc private func handleOpenNoteEditorNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let url = userInfo["url"] as? URL else {
            // No URL provided - log and return (don't show panel)
            print("📝 No file selected - panel not shown")
            return
        }
        
        // Close any existing editor
        closeCurrentEditor()
        
        // Load existing note
        let existingNote = NoteStorage.shared.getNote(for: url)
        
        // Create and show editor
        currentEditorWindow = NoteEditorWindowController(
            targetURL: url,
            existingNote: existingNote
        )
        currentEditorWindow?.show()
        
        print("📝 Opening editor for: \(url.lastPathComponent)")
    }
    
    @objc private func handleEditorDismissed(_ notification: Notification) {
        // Only clear if it's our current editor
        if let dismissedController = notification.object as? NoteEditorWindowController,
           dismissedController === currentEditorWindow {
            currentEditorWindow = nil
        }
    }
    
    private func closeCurrentEditor() {
        currentEditorWindow?.dismiss()
        currentEditorWindow = nil
    }
    
    // MARK: - App Lifecycle
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up
        NotificationCenter.default.removeObserver(self)
        ShortcutManager.shared.unregisterShortcut()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

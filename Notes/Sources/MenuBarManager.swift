import Cocoa
import SwiftUI

class MenuBarManager: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    weak var preferencesWindowController: PreferencesWindowController?
    
    override init() {
        super.init()
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set menu bar icon (using custom icon from Assets.xcassets)
        if let button = statusItem?.button {
            // Try to load custom icon from asset catalog
            if let image = NSImage(named: "MenuBarIcon") {
                image.isTemplate = true  // Enable template rendering for color tinting
                button.image = image
            } else {
                // Fallback to SF Symbol if asset not found
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                let fallbackImage = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Notes")
                button.image = fallbackImage?.withSymbolConfiguration(config)
            }
        }
        
        // Create menu
        menu = NSMenu()
        menu?.delegate = self
        
        // Note: Menu items will be built dynamically in menuNeedsUpdate
        
        // Attach menu to status item
        statusItem?.menu = menu
    }
    
    // Build menu items dynamically based on Finder selection
    private func buildMenuItems() {
        menu?.removeAllItems()
        
        // Check if there's a Finder selection
        let selectedItem = FinderSelectionMonitor.shared.getSelectedItem()
        
        if let url = selectedItem {
            let hasNote = NoteStorage.shared.hasNote(for: url.path)
            
            if hasNote {
                // Show Edit and Remove options
                addMenuItem(title: "Edit Note", action: #selector(editNote), keyEquivalent: "")
                addMenuItem(title: "Remove Note", action: #selector(removeNote), keyEquivalent: "")
            } else {
                // Show Add option
                addMenuItem(title: "Add Note", action: #selector(addNote), keyEquivalent: "")
            }
            
            menu?.addItem(NSMenuItem.separator())
        }
        
        // Standard menu items
        addMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: ",")
        addMenuItem(title: "Send Feedback", action: #selector(sendFeedback), keyEquivalent: "f")
        menu?.addItem(NSMenuItem.separator())
        addMenuItem(title: "About Notes", action: #selector(showAbout), keyEquivalent: "")
        addMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
    }
    
    private func addMenuItem(title: String, action: Selector, keyEquivalent: String) {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        menuItem.target = self
        menu?.addItem(menuItem)
    }
    
    // MARK: - Menu Actions
    
    @objc private func openPreferences() {
        preferencesWindowController?.show()
    }
    
    @objc private func sendFeedback() {
        print("Opening Send Feedback...")
        // TODO: Open feedback form or email
        if let url = URL(string: "mailto:feedback@example.com?subject=Notes%20Feedback") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func showAbout() {
        // Create custom about panel with app icon
        let alert = NSAlert()
        alert.messageText = "Notes"
        alert.informativeText = "Version 1.0\n\nA minimal macOS utility for attaching notes to files and folders.\n\n© 2026 All rights reserved."
        alert.alertStyle = .informational
        
        // Try to set app icon
        if let appIcon = NSImage(named: "AppIcon") {
            alert.icon = appIcon
        } else if let appIcon = NSApp.applicationIconImage {
            alert.icon = appIcon
        }
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    
    // MARK: - Icon Customization
    
    func updateIconColor(_ color: NSColor) {
        if let button = statusItem?.button {
            button.contentTintColor = color
        }
    }
    
    // MARK: - NSMenuDelegate
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        buildMenuItems()
    }
    
    // MARK: - Note Actions
    
    @objc private func addNote() {
        guard let url = FinderSelectionMonitor.shared.getSelectedItem() else {
            print("No file selected")
            return
        }
        
        let editorWindow = NoteEditorWindowController(filePath: url.path, existingNote: nil)
        editorWindow.show()
    }
    
    @objc private func editNote() {
        guard let url = FinderSelectionMonitor.shared.getSelectedItem() else {
            print("No file selected")
            return
        }
        
        guard let note = NoteStorage.shared.getNote(for: url.path) else {
            print("No note found for: \(url.path)")
            return
        }
        
        let editorWindow = NoteEditorWindowController(filePath: url.path, existingNote: note)
        editorWindow.show()
    }
    
    @objc private func removeNote() {
        guard let url = FinderSelectionMonitor.shared.getSelectedItem() else {
            print("No file selected")
            return
        }
        
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Remove Note"
        alert.informativeText = "Are you sure you want to remove the note for \"\(url.lastPathComponent)\"?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NoteStorage.shared.removeNote(for: url.path)
            print("Removed note for: \(url.path)")
        }
    }
}

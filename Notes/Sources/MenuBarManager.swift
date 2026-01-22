import Cocoa
import SwiftUI

class MenuBarManager: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    weak var preferencesWindowController: PreferencesWindowController?
    
    // Cache the Finder selection when menu opens (before focus changes)
    private var cachedSelection: URL?
    
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
        
        // Attach menu to status item
        statusItem?.menu = menu
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        // Use cached selection which survives brief focus loss
        // The cache is refreshed when user clicks in Finder or Finder becomes active
        cachedSelection = FinderSelectionMonitor.shared.getCachedOrCurrentSelection()
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        buildMenuItems()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        // Clear cached selection after menu closes
        cachedSelection = nil
    }
    
    // MARK: - Menu Building
    
    private func buildMenuItems() {
        menu?.removeAllItems()
        
        // Use cached selection (captured in menuWillOpen)
        if let url = cachedSelection {
            // Show the filename as a header (disabled item)
            let fileItem = NSMenuItem(title: url.lastPathComponent, action: nil, keyEquivalent: "")
            fileItem.isEnabled = false
            menu?.addItem(fileItem)
            
            let hasNote = NoteStorage.shared.hasNote(for: url)
            
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
        addMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        addMenuItem(title: "Send Feedback", action: #selector(sendFeedback), keyEquivalent: "")
        menu?.addItem(NSMenuItem.separator())
        addMenuItem(title: "About Notes", action: #selector(showAbout), keyEquivalent: "")
        addMenuItem(title: "Quit Notes", action: #selector(quitApp), keyEquivalent: "q")
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
        if let url = URL(string: "mailto:feedback@example.com?subject=Notes%20Feedback") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Notes"
        alert.informativeText = "Version 1.0\n\nA minimal macOS utility for attaching notes to files and folders.\n\n© 2026 All rights reserved."
        alert.alertStyle = .informational
        
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
    
    // MARK: - Note Actions
    
    @objc private func addNote() {
        guard let url = cachedSelection else {
            print("No file selected")
            return
        }
        
        // Post notification to open editor (AppDelegate handles window creation)
        NotificationCenter.default.post(
            name: .openNoteEditor,
            object: nil,
            userInfo: ["url": url]
        )
    }
    
    @objc private func editNote() {
        guard let url = cachedSelection else {
            print("No file selected")
            return
        }
        
        // Post notification to open editor
        NotificationCenter.default.post(
            name: .openNoteEditor,
            object: nil,
            userInfo: ["url": url]
        )
    }
    
    @objc private func removeNote() {
        guard let url = cachedSelection else {
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
            NoteStorage.shared.removeNote(for: url)
            print("✅ Removed note for: \(url.lastPathComponent)")
        }
    }
}

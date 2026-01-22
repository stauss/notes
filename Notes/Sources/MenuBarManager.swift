import Cocoa
import SwiftUI

class MenuBarManager: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    weak var preferencesWindowController: PreferencesWindowController?
    
    // Cache the Finder selections when menu opens (before focus changes)
    private var cachedSelections: [URL] = []
    
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
        // Use cached selections which survive brief focus loss
        // The cache is refreshed when user clicks in Finder or Finder becomes active
        cachedSelections = FinderSelectionMonitor.shared.getCachedOrCurrentSelections()
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        buildMenuItems()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        // Clear cached selections after menu closes
        cachedSelections = []
    }
    
    // MARK: - Menu Building
    
    private func buildMenuItems() {
        menu?.removeAllItems()
        
        if cachedSelections.isEmpty {
            // No selection - show hint
            let noSelectionItem = NSMenuItem(title: "Select a file in Finder", action: nil, keyEquivalent: "")
            noSelectionItem.isEnabled = false
            menu?.addItem(noSelectionItem)
            menu?.addItem(NSMenuItem.separator())
        } else if cachedSelections.count == 1 {
            // Single selection
            buildSingleSelectionMenu(for: cachedSelections[0])
        } else {
            // Multiple selections
            buildMultiSelectionMenu(for: cachedSelections)
        }
        
        // Standard menu items
        menu?.addItem(NSMenuItem.separator())
        addMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        menu?.addItem(NSMenuItem.separator())
        addMenuItem(title: "Quit Notes", action: #selector(quitApp), keyEquivalent: "q")
    }
    
    /// Build menu for single file selection
    private func buildSingleSelectionMenu(for url: URL) {
        // Show status line
        let statusItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu?.addItem(statusItem)
        
        let hasNote = NoteStorage.shared.hasNote(for: url)
        
        if hasNote {
            // Show Edit, Copy, and Remove options
            addMenuItem(title: "Edit Note", action: #selector(editNote), keyEquivalent: "")
            addMenuItem(title: "Copy Note", action: #selector(copyNote), keyEquivalent: "c")
            addMenuItem(title: "Remove Note", action: #selector(removeNote), keyEquivalent: "")
        } else {
            // Show Add option
            addMenuItem(title: "Add Note", action: #selector(addNote), keyEquivalent: "")
        }
        
        menu?.addItem(NSMenuItem.separator())
    }
    
    /// Build menu for multiple file selections
    private func buildMultiSelectionMenu(for urls: [URL]) {
        let count = urls.count
        let itemsWithNotes = urls.filter { NoteStorage.shared.hasNote(for: $0) }
        let itemsWithoutNotes = urls.filter { !NoteStorage.shared.hasNote(for: $0) }
        
        // Show status line
        let statusItem = NSMenuItem(title: count == 1 ? "1 item selected" : "\(count) items selected", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu?.addItem(statusItem)
        
        // Show how many have notes
        if !itemsWithNotes.isEmpty {
            let noteCountItem = NSMenuItem(title: "  \(itemsWithNotes.count) with notes", action: nil, keyEquivalent: "")
            noteCountItem.isEnabled = false
            menu?.addItem(noteCountItem)
        }
        
        menu?.addItem(NSMenuItem.separator())
        
        // Add Notes to items without notes
        if !itemsWithoutNotes.isEmpty {
            let addTitle = itemsWithoutNotes.count == 1
                ? "Add Note to \(itemsWithoutNotes[0].lastPathComponent)"
                : "Add Notes to \(itemsWithoutNotes.count) items..."
            addMenuItem(title: addTitle, action: #selector(addNotesToSelection), keyEquivalent: "")
        }
        
        // Remove Notes from items with notes
        if !itemsWithNotes.isEmpty {
            let removeTitle = itemsWithNotes.count == 1
                ? "Remove Note from \(itemsWithNotes[0].lastPathComponent)"
                : "Remove Notes from \(itemsWithNotes.count) items..."
            addMenuItem(title: removeTitle, action: #selector(removeNotesFromSelection), keyEquivalent: "")
        }
        
        menu?.addItem(NSMenuItem.separator())
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
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Icon Customization
    
    func updateIconColor(_ color: NSColor) {
        if let button = statusItem?.button {
            button.contentTintColor = color
        }
    }
    
    // MARK: - Single Selection Note Actions
    
    @objc private func addNote() {
        guard let url = cachedSelections.first else {
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
        guard let url = cachedSelections.first else {
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
    
    @objc private func copyNote() {
        guard let url = cachedSelections.first else {
            print("No file selected")
            return
        }
        
        guard let note = NoteStorage.shared.getNote(for: url) else {
            print("No note found for: \(url.lastPathComponent)")
            return
        }
        
        // Copy note content to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Format: Title (if exists) + Body
        var content = ""
        if !note.title.isEmpty {
            content = note.title + "\n\n"
        }
        content += note.body
        
        pasteboard.setString(content, forType: .string)
        print("✅ Copied note to clipboard: \(url.lastPathComponent)")
    }
    
    @objc private func removeNote() {
        guard let url = cachedSelections.first else {
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
    
    // MARK: - Multi-Selection Note Actions
    
    @objc private func addNotesToSelection() {
        let itemsWithoutNotes = cachedSelections.filter { !NoteStorage.shared.hasNote(for: $0) }
        
        guard !itemsWithoutNotes.isEmpty else {
            print("All selected items already have notes")
            return
        }
        
        if itemsWithoutNotes.count == 1 {
            // Single item - open editor directly
            NotificationCenter.default.post(
                name: .openNoteEditor,
                object: nil,
                userInfo: ["url": itemsWithoutNotes[0]]
            )
        } else {
            // Multiple items - show batch add dialog
            showBatchAddDialog(for: itemsWithoutNotes)
        }
    }
    
    @objc private func removeNotesFromSelection() {
        let itemsWithNotes = cachedSelections.filter { NoteStorage.shared.hasNote(for: $0) }
        
        guard !itemsWithNotes.isEmpty else {
            print("No selected items have notes")
            return
        }
        
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Remove Notes"
        alert.informativeText = "Are you sure you want to remove notes from \(itemsWithNotes.count) item(s)?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove All")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            var removedCount = 0
            for url in itemsWithNotes {
                if NoteStorage.shared.removeNote(for: url) {
                    removedCount += 1
                }
            }
            print("✅ Removed notes from \(removedCount) item(s)")
        }
    }
    
    /// Show dialog for adding notes to multiple items at once
    private func showBatchAddDialog(for urls: [URL]) {
        let alert = NSAlert()
        alert.messageText = "Add Notes to \(urls.count) Items"
        alert.informativeText = "Would you like to add notes to each item individually?"
        alert.addButton(withTitle: "Add Individually")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Open editor for first item, user can continue with others
            if let firstUrl = urls.first {
                NotificationCenter.default.post(
                    name: .openNoteEditor,
                    object: nil,
                    userInfo: ["url": firstUrl, "pendingUrls": Array(urls.dropFirst())]
                )
            }
        }
    }
}

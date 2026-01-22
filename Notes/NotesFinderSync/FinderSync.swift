import Cocoa
import FinderSync

class FinderSync: FIFinderSync {
    
    // MARK: - Constants
    
    private let xattrName = "com.apple.metadata:kMDItemFinderComment"
    private let notePrefix = "NOTES:v1"
    private let badgeIdentifier = "HasNote"
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        NSLog("NotesFinderSync: Extension initialized")
        
        // Register the badge image
        if let badgeImage = NSImage(named: "NoteBadge") {
            FIFinderSyncController.default().setBadgeImage(
                badgeImage,
                label: "Has Note",
                forBadgeIdentifier: badgeIdentifier
            )
        } else {
            // Fallback: Create a simple badge programmatically
            let badge = createDefaultBadge()
            FIFinderSyncController.default().setBadgeImage(
                badge,
                label: "Has Note",
                forBadgeIdentifier: badgeIdentifier
            )
        }
        
        // Monitor user's home directory (includes Desktop, Documents, Downloads, etc.)
        // This covers most common locations where users store files
        FIFinderSyncController.default().directoryURLs = [
            URL(fileURLWithPath: NSHomeDirectory())
        ]
    }
    
    // MARK: - FIFinderSync Protocol
    
    /// Called by Finder to request a badge for a specific file/folder
    override func requestBadgeIdentifier(for url: URL) {
        // Perform real-time xattr check
        if hasNote(for: url) {
            FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
        } else {
            // Clear any existing badge
            FIFinderSyncController.default().setBadgeIdentifier(nil, for: url)
        }
    }
    
    // MARK: - Toolbar Item (Optional)
    
    override var toolbarItemName: String {
        return "Notes"
    }
    
    override var toolbarItemToolTip: String {
        return "View or add notes to selected items"
    }
    
    override var toolbarItemImage: NSImage {
        if let image = NSImage(named: "MenuBarIcon") {
            return image
        }
        return NSImage(systemSymbolName: "note.text", accessibilityDescription: "Notes")!
    }
    
    // MARK: - Context Menu (Optional)
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "Notes")
        
        switch menuKind {
        case .contextualMenuForItems, .contextualMenuForContainer:
            // Add menu items for right-click context menu
            let addItem = NSMenuItem(title: "Add Note", action: #selector(addNoteAction(_:)), keyEquivalent: "")
            addItem.target = self
            menu.addItem(addItem)
            
        case .toolbarItemMenu:
            // Toolbar dropdown menu
            let addItem = NSMenuItem(title: "Add Note to Selection", action: #selector(addNoteAction(_:)), keyEquivalent: "")
            addItem.target = self
            menu.addItem(addItem)
            
        @unknown default:
            break
        }
        
        return menu
    }
    
    @objc func addNoteAction(_ sender: AnyObject?) {
        // Get the selected items
        guard let items = FIFinderSyncController.default().selectedItemURLs(), !items.isEmpty else {
            NSLog("NotesFinderSync: No items selected")
            return
        }
        
        // Launch main app with the selected URL
        // The main app will handle showing the note editor
        if let url = items.first {
            let mainAppURL = URL(string: "notes://open?path=\(url.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
            if let appURL = mainAppURL {
                NSWorkspace.shared.open(appURL)
            }
        }
    }
    
    // MARK: - Note Detection
    
    /// Check if a file has a note attached (real-time xattr check)
    private func hasNote(for url: URL) -> Bool {
        let path = url.path
        
        // Get the size of the extended attribute
        let size = getxattr(path, xattrName, nil, 0, 0, 0)
        guard size > 0 else { return false }
        
        // Read the attribute data
        var data = Data(count: size)
        let result = data.withUnsafeMutableBytes { bytes in
            getxattr(path, xattrName, bytes.baseAddress, size, 0, 0)
        }
        guard result > 0 else { return false }
        
        // Decode from plist format and check for our note prefix
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let comment = plist as? String else {
            return false
        }
        
        // Check if the comment starts with our note format header
        return comment.hasPrefix(notePrefix)
    }
    
    // MARK: - Helpers
    
    /// Create a default badge image programmatically (fallback)
    private func createDefaultBadge() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw a small note icon
        let rect = NSRect(x: 2, y: 2, width: 12, height: 12)
        
        // Background circle
        NSColor.systemBlue.setFill()
        let path = NSBezierPath(ovalIn: rect)
        path.fill()
        
        // Note symbol (simple lines)
        NSColor.white.setStroke()
        let linePath = NSBezierPath()
        linePath.lineWidth = 1.5
        linePath.move(to: NSPoint(x: 5, y: 10))
        linePath.line(to: NSPoint(x: 11, y: 10))
        linePath.move(to: NSPoint(x: 5, y: 7))
        linePath.line(to: NSPoint(x: 11, y: 7))
        linePath.move(to: NSPoint(x: 5, y: 4))
        linePath.line(to: NSPoint(x: 9, y: 4))
        linePath.stroke()
        
        image.unlockFocus()
        
        return image
    }
}

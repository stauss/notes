import Foundation
import AppKit

class FinderSelectionMonitor {
    static let shared = FinderSelectionMonitor()
    
    // Cached selection that persists briefly after Finder loses focus
    private var cachedSelection: URL?
    private var cachedSelections: [URL] = []
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 2.0  // 2 second validity
    
    private init() {
        print("🔧 FinderSelectionMonitor initialized")
        setupFinderMonitor()
    }
    
    // MARK: - Public API (Single Selection)
    
    /// Get the currently selected file/folder in Finder (fresh query, single item)
    func getSelectedItem() -> URL? {
        return getSelectedItems().first
    }
    
    // MARK: - Public API (Multi-Selection)
    
    /// Get all currently selected files/folders in Finder (fresh query)
    func getSelectedItems() -> [URL] {
        print("🔍 Querying Finder for selection...")
        
        // Script to get all selected items as a list of paths
        let multiSelectScript = """
        tell application "Finder"
            set theSelection to selection
            if theSelection is {} then
                return ""
            end if
            set pathList to ""
            repeat with theItem in theSelection
                try
                    set itemPath to POSIX path of (theItem as alias)
                    if pathList is "" then
                        set pathList to itemPath
                    else
                        set pathList to pathList & "|||" & itemPath
                    end if
                end try
            end repeat
            return pathList
        end tell
        """
        
        if let result = runOsascript(multiSelectScript), !result.isEmpty {
            // Parse the delimiter-separated paths
            let paths = result.components(separatedBy: "|||")
            var urls: [URL] = []
            
            for path in paths {
                let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanPath.isEmpty {
                    let url = URL(fileURLWithPath: cleanPath)
                    if FileManager.default.fileExists(atPath: url.path) {
                        urls.append(url)
                    }
                }
            }
            
            if !urls.isEmpty {
                print("✅ Found \(urls.count) selected item(s)")
                return urls
            }
        }
        
        // Fallback: Try single-item scripts
        if let singleUrl = getSelectedItemFallback() {
            return [singleUrl]
        }
        
        print("ℹ️ No selection detected")
        return []
    }
    
    /// Fallback method for single selection (various approaches)
    private func getSelectedItemFallback() -> URL? {
        let scripts = [
            // Approach 1: Get selection as text (most compatible)
            """
            tell application "Finder"
                set theSelection to selection
                if theSelection is not {} then
                    set theItem to item 1 of theSelection
                    return POSIX path of (theItem as text)
                end if
            end tell
            return ""
            """,
            // Approach 2: Use alias conversion
            """
            tell application "Finder"
                set theSelection to selection
                if theSelection is not {} then
                    try
                        return POSIX path of (item 1 of theSelection as alias)
                    on error
                        set theItem to item 1 of theSelection
                        return POSIX path of (theItem as string)
                    end try
                end if
            end tell
            return ""
            """,
            // Approach 3: Get URL directly
            """
            tell application "Finder"
                if selection is not {} then
                    set sel to selection
                    set thePath to (URL of item 1 of sel)
                    return thePath
                end if
            end tell
            return ""
            """
        ]
        
        for (index, script) in scripts.enumerated() {
            if let result = runOsascript(script) {
                var path = result
                if path.hasPrefix("file://") {
                    if let url = URL(string: path) {
                        path = url.path
                    }
                }
                if !path.isEmpty {
                    let url = URL(fileURLWithPath: path)
                    if FileManager.default.fileExists(atPath: url.path) {
                        print("✅ Found selected file (fallback \(index + 1)): \(url.lastPathComponent)")
                        return url
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Run AppleScript via osascript command (better permission handling)
    private func runOsascript(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("   osascript exit code: \(process.terminationStatus)")
            print("   osascript output: '\(output ?? "nil")'")
            
            return output
        } catch {
            print("   osascript error: \(error)")
            return nil
        }
    }
    
    /// Run AppleScript via NSAppleScript (fallback)
    private func runNSAppleScript(_ script: String) -> String? {
        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }
        
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            print("   NSAppleScript error: \(error["NSAppleScriptErrorMessage"] ?? "unknown")")
            return nil
        }
        
        return result.stringValue
    }
    
    /// Get cached selection if still valid, otherwise fetch fresh and cache it
    /// This survives brief focus loss (e.g., when clicking menu bar)
    func getCachedOrCurrentSelection() -> URL? {
        return getCachedOrCurrentSelections().first
    }
    
    /// Get cached selections (multi-select) if still valid, otherwise fetch fresh and cache
    /// This survives brief focus loss (e.g., when clicking menu bar)
    func getCachedOrCurrentSelections() -> [URL] {
        print("🔍 getCachedOrCurrentSelections called")
        
        // Check cache status
        if let timestamp = cacheTimestamp, !cachedSelections.isEmpty {
            let age = Date().timeIntervalSince(timestamp)
            print("   Cache exists: \(cachedSelections.count) item(s), age: \(String(format: "%.2f", age))s")
            
            if age < cacheValidityDuration {
                print("📋 Using cached selections: \(cachedSelections.count) item(s)")
                return cachedSelections
            } else {
                print("   Cache expired (>\(cacheValidityDuration)s)")
            }
        } else {
            print("   No cache available")
        }
        
        // Get fresh selections and cache them
        let selections = getSelectedItems()
        cachedSelections = selections
        cachedSelection = selections.first
        cacheTimestamp = Date()
        
        print("💾 Cached \(selections.count) selection(s)")
        
        return selections
    }
    
    /// Manually refresh the cache (call when Finder becomes active)
    func refreshCache() {
        print("🔄 Refreshing cache...")
        let selections = getSelectedItems()
        cachedSelections = selections
        cachedSelection = selections.first
        cacheTimestamp = Date()
        print("🔄 Cache refreshed: \(selections.count) item(s)")
    }
    
    /// Check if Finder has an active selection
    func hasSelection() -> Bool {
        return !getCachedOrCurrentSelections().isEmpty
    }
    
    /// Get the count of selected items
    func selectionCount() -> Int {
        return getCachedOrCurrentSelections().count
    }
    
    // MARK: - Finder Monitoring
    
    private func setupFinderMonitor() {
        print("🔧 Setting up Finder monitors...")
        
        // Monitor when Finder becomes the active application
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        print("   ✓ Registered for app activation notifications")
        
        // Also monitor mouse clicks to refresh cache when user clicks in Finder
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            // Check if Finder is the frontmost app after a click
            if let frontApp = NSWorkspace.shared.frontmostApplication,
               frontApp.bundleIdentifier == "com.apple.finder" {
                // Delay slightly to let Finder's selection update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.refreshCache()
                }
            }
        }
        print("   ✓ Registered global mouse monitor")
    }
    
    @objc private func applicationDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        print("📱 App activated: \(app.localizedName ?? "unknown") (\(app.bundleIdentifier ?? "no bundle id"))")
        
        guard app.bundleIdentifier == "com.apple.finder" else {
            return
        }
        
        print("📁 Finder became active, will refresh cache...")
        
        // Delay slightly to let Finder's selection settle, then cache
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.refreshCache()
        }
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

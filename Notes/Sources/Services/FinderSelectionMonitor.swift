import Foundation
import AppKit

class FinderSelectionMonitor {
    static let shared = FinderSelectionMonitor()
    
    // Cached selection that persists briefly after Finder loses focus
    private var cachedSelection: URL?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 2.0  // 2 second validity
    
    private init() {
        print("🔧 FinderSelectionMonitor initialized")
        setupFinderMonitor()
    }
    
    // MARK: - Public API
    
    /// Get the currently selected file/folder in Finder (fresh query)
    func getSelectedItem() -> URL? {
        print("🔍 Querying Finder for selection...")
        
        // Try multiple scripts with different approaches to handle various file types
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
            // Approach 2: Use insertion location as fallback
            """
            tell application "Finder"
                set theSelection to selection
                if theSelection is not {} then
                    try
                        return POSIX path of (item 1 of theSelection as alias)
                    on error
                        -- Try getting the path differently
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
            print("   Trying script approach \(index + 1)...")
            if let result = runOsascript(script) {
                // Clean up the result - might be a file:// URL or a path
                var path = result
                if path.hasPrefix("file://") {
                    if let url = URL(string: path) {
                        path = url.path
                    }
                }
                if !path.isEmpty && path != "" {
                    let url = URL(fileURLWithPath: path)
                    // Verify the file exists
                    if FileManager.default.fileExists(atPath: url.path) {
                        print("✅ Found selected file (approach \(index + 1)): \(url.lastPathComponent)")
                        return url
                    }
                }
            }
        }
        
        print("ℹ️ No selection detected")
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
        print("🔍 getCachedOrCurrentSelection called")
        
        // Check cache status
        if let cached = cachedSelection, let timestamp = cacheTimestamp {
            let age = Date().timeIntervalSince(timestamp)
            print("   Cache exists: \(cached.lastPathComponent), age: \(String(format: "%.2f", age))s")
            
            if age < cacheValidityDuration {
                print("📋 Using cached selection: \(cached.lastPathComponent)")
                return cached
            } else {
                print("   Cache expired (>\(cacheValidityDuration)s)")
            }
        } else {
            print("   No cache available")
        }
        
        // Get fresh selection and cache it
        let selection = getSelectedItem()
        cachedSelection = selection
        cacheTimestamp = Date()
        
        if let sel = selection {
            print("💾 Cached new selection: \(sel.lastPathComponent)")
        } else {
            print("💾 Cached nil selection")
        }
        
        return selection
    }
    
    /// Manually refresh the cache (call when Finder becomes active)
    func refreshCache() {
        print("🔄 Refreshing cache...")
        cachedSelection = getSelectedItem()
        cacheTimestamp = Date()
        if let cached = cachedSelection {
            print("🔄 Cache refreshed: \(cached.lastPathComponent)")
        } else {
            print("🔄 Cache refreshed: (no selection)")
        }
    }
    
    /// Check if Finder has an active selection
    func hasSelection() -> Bool {
        return getCachedOrCurrentSelection() != nil
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

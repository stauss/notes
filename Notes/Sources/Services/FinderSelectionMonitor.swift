import Foundation
import AppKit

class FinderSelectionMonitor {
    static let shared = FinderSelectionMonitor()
    
    private init() {}
    
    /// Get the currently selected file/folder in Finder
    func getSelectedItem() -> URL? {
        // Use AppleScript to get the selected item from Finder
        let script = """
        tell application "Finder"
            if (count of selection) > 0 then
                set selectedItem to item 1 of selection
                return POSIX path of (selectedItem as alias)
            else
                return ""
            end if
        end tell
        """
        
        guard let appleScript = NSAppleScript(source: script) else {
            print("❌ Failed to create AppleScript")
            return nil
        }
        
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            print("❌ AppleScript error: \(error)")
            print("💡 Tip: Grant Automation permissions in System Settings → Privacy & Security → Automation → Notes → Finder")
            return nil
        }
        
        guard let path = result.stringValue, !path.isEmpty else {
            print("ℹ️ No file selected in Finder")
            return nil
        }
        
        print("✅ Found selected file: \(path)")
        return URL(fileURLWithPath: path)
    }
    
    /// Check if Finder has an active selection
    func hasSelection() -> Bool {
        return getSelectedItem() != nil
    }
}

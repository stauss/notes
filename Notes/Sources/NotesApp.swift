import SwiftUI

@main
struct NotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // No scenes needed - this is a menu bar-only app
        // All UI is managed through AppDelegate and MenuBarManager
        // Removing WindowGroup prevents blank window on launch
        Settings {
            EmptyView()
        }
    }
}

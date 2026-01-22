# Notes - macOS Menu Bar Application

A minimal macOS utility that runs as a **background app** (menu bar only) allowing users to attach plain-text notes to files or folders via a global keyboard shortcut.

## Application Architecture

### Background App (Menu Bar Only)
- **No Dock Icon** - Runs as `LSUIElement` background application
- **Menu Bar Presence** - Icon appears in macOS top toolbar only
- **On-Demand UI** - Windows only appear when triggered by shortcuts or menu clicks
- **Global Shortcuts** - Accessible system-wide via customizable keyboard shortcuts

### Technology Stack
- **Swift + SwiftUI** - Native macOS development
- **AppKit** - Menu bar integration and global shortcuts
- **UserDefaults** - Settings persistence
- **Extended Attributes (xattr)** - Note storage attached to files

## Features

### Menu Bar Dropdown
1. **Preferences** (⌘,) - Settings window for shortcuts and appearance
2. **Send Feedback** (⌘F) - User feedback submission
3. **About** - Application information and version
4. **Quit** (⌘Q) - Terminate application

### Preferences/Settings
- **Keyboard Shortcut Customization** - Set global shortcut for note editor
- **Icon Color/Badge Customization** - Personalize menu bar icon appearance
- **Launch at Login** - Auto-start with macOS
- **Note Storage Location** - Configure where notes are saved

### Note Management
- **Add/Edit Notes** - Attach plain-text notes to any file or folder
- **Global Shortcut Access** - Quick access via keyboard (default: ⌘⇧N)
- **Persistent Storage** - Notes survive file moves and system restarts
- **Finder Integration** - Works with current Finder selection

## Project Structure

```
notes/
├── Notes.xcodeproj/          # Xcode project
├── Notes/
│   ├── NotesApp.swift        # Main app entry point
│   ├── AppDelegate.swift     # App lifecycle & menu bar
│   ├── MenuBarManager.swift  # Menu bar icon & dropdown
│   ├── Views/
│   │   ├── NoteEditorView.swift      # Add/edit note window
│   │   ├── PreferencesView.swift     # Settings window
│   │   └── AboutView.swift           # About window
│   ├── Models/
│   │   ├── Note.swift                # Note data model
│   │   └── Settings.swift            # App settings model
│   ├── Services/
│   │   ├── ShortcutManager.swift     # Global shortcut handling
│   │   ├── NoteStorage.swift         # Note persistence
│   │   └── FileMonitor.swift         # File system monitoring
│   └── Resources/
│       ├── Assets.xcassets           # Icons and images
│       └── Info.plist                # App configuration
└── README.md
```

## Development Setup

### Requirements
- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- Swift 5.9+

### Building
```bash
# Open project in Xcode
open Notes.xcodeproj

# Or build from command line
xcodebuild -project Notes.xcodeproj -scheme Notes -configuration Release
```

### Running
```bash
# Run from Xcode (⌘R)
# Or from command line
xcodebuild -project Notes.xcodeproj -scheme Notes -configuration Debug
open build/Debug/Notes.app
```

## Usage

1. **Launch** - App appears in menu bar (no Dock icon)
2. **Add Note** - Press global shortcut (⌘⇧N) or click menu bar icon
3. **Customize** - Open Preferences to set shortcuts and icon color
4. **Manage** - Access notes via Finder context menu or shortcut

## License

MIT License - See LICENSE file for details

# Notes - Menu Bar Application

A minimal macOS menu bar application for attaching plain-text notes to files and folders.

## Project Structure

```
Notes/
├── Package.swift              # Swift Package Manager configuration
├── Sources/
│   ├── NotesApp.swift        # Main app entry point
│   ├── AppDelegate.swift     # App lifecycle & menu bar setup
│   ├── MenuBarManager.swift  # Menu bar icon & dropdown management
│   ├── Models/
│   │   ├── AppSettings.swift # User settings with UserDefaults
│   │   └── Note.swift        # Note data model
│   ├── Views/               # SwiftUI views (to be added)
│   ├── Services/            # Business logic services (to be added)
│   └── Resources/
│       └── Info.plist       # App configuration (LSUIElement=true)
└── .build/                  # Build output directory
```

## Building

```bash
swift build
```

## Running

```bash
# Run the built executable
open .build/debug/Notes

# Or build and run in one command
swift run
```

## Features Implemented

### Phase 1: Project Foundation ✅
- Swift Package Manager project structure
- Info.plist configured with LSUIElement (background app)
- macOS 13.0+ deployment target
- SF Symbol menu bar icon (note.text)

### Phase 2: Menu Bar Core ✅
- Menu bar status item
- Dropdown menu with 4 items:
  - **Preferences** (⌘,) - Opens preferences window (TODO)
  - **Send Feedback** (⌘F) - Opens email client
  - **About** - Shows standard About panel
  - **Quit** (⌘Q) - Terminates application
- Icon color customization support
- No Dock icon (background app only)

### Phase 3: Settings/Preferences System (In Progress)
- AppSettings model with UserDefaults persistence
- TODO: Preferences UI window

## Next Steps

1. Create Preferences window with:
   - Global shortcut recorder
   - Icon color picker
   - Launch at login toggle
   
2. Implement global keyboard shortcut handling

3. Create Note Editor UI

4. Implement note storage with extended attributes (xattr)

## Development Notes

- The app uses `NSApp.setActivationPolicy(.accessory)` to hide from Dock
- `LSUIElement` in Info.plist ensures background app behavior
- Menu bar icon uses SF Symbol `note.text`
- Settings model renamed to `AppSettings` to avoid conflict with SwiftUI.Settings

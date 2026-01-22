# Notes App - Agent Onboarding Guide

Quick reference for AI agents working on this macOS menu bar app.

---

## What This App Does

**Notes** is a macOS menu bar utility that attaches plain-text notes to files and folders. Users select a file in Finder, press a global shortcut (⌃⌥N), and type a note. Notes are visible in Finder's "Get Info" panel.

**Key behaviors:**

- Runs as background app (no Dock icon, `LSUIElement = true`)
- Global keyboard shortcut toggles note editor (press again to close)
- Notes stored in SQLite database + Finder Comments (hybrid storage)
- Dark, Raycast-inspired floating editor UI
- File bookmarks track moved/renamed files

---

## Tech Stack

| Component | Technology                                            |
| --------- | ----------------------------------------------------- |
| Language  | Swift 5.9+                                            |
| Platform  | macOS 13.0+ (Ventura)                                 |
| UI        | SwiftUI (editor) + AppKit (menu bar, windows)         |
| Storage   | **Hybrid**: SQLite database + xattr (Finder Comments) |
| Build     | Swift Package Manager                                 |

---

## Project Structure

```
Notes/
├── Package.swift                    # SPM manifest
├── Sources/
│   ├── NotesApp.swift              # @main entry point
│   ├── AppDelegate.swift           # App lifecycle, window management, global shortcut
│   ├── MenuBarManager.swift        # Status item, dropdown menu, actions
│   ├── Models/
│   │   ├── Note.swift              # Note struct with title/body, encoding, bookmarkData
│   │   └── Settings.swift          # AppSettings (UserDefaults wrapper)
│   ├── Services/
│   │   ├── NoteDatabase.swift      # SQLite storage (PRIMARY) - singleton
│   │   ├── NoteStorage.swift       # Hybrid storage coordinator (database + xattr)
│   │   ├── FinderSelectionMonitor.swift  # Gets Finder selection via AppleScript
│   │   ├── ShortcutManager.swift   # Global hotkey registration (Carbon)
│   │   └── LaunchAtLoginManager.swift
│   ├── Views/
│   │   ├── NoteEditorView.swift          # SwiftUI editor UI
│   │   ├── NoteEditorViewModel.swift     # Editor state management
│   │   ├── NoteEditorWindowController.swift  # NSPanel host with vibrancy
│   │   ├── PreferencesView.swift         # Settings UI (SwiftUI)
│   │   ├── PreferencesViewModel.swift    # Preferences state
│   │   ├── PreferencesWindowController.swift  # Preferences NSWindow host
│   │   └── ShortcutRecorderView.swift    # Custom shortcut input field
│   └── Resources/
│       ├── Assets.xcassets/
│       │   ├── AppIcon.appiconset/      # App icons (16-1024px)
│       │   └── MenuBarIcon.imageset/    # Menu bar icon (18, 36px)
│       └── Info.plist
```

---

## Storage Architecture

The app uses **hybrid storage** for reliability and Finder visibility:

```
┌─────────────────────────────────────────────────────────┐
│                     NoteStorage                         │
│              (Coordinator - hybrid logic)               │
├─────────────────────────────────────────────────────────┤
│                         │                               │
│    ┌────────────────────┴────────────────────┐          │
│    ▼                                         ▼          │
│ NoteDatabase                            xattr/Finder    │
│ (SQLite - PRIMARY)                      (WRITE-THROUGH) │
│                                                         │
│ ~/Library/Application Support/Notes/notes.db            │
└─────────────────────────────────────────────────────────┘
```

### Storage Flow

**Save:**

1. Write to SQLite database (primary, fast lookup, bookmark tracking)
2. Write to xattr via AppleScript (Finder visibility in Get Info)

**Read:**

1. Try database first (fast, handles moved files via bookmark)
2. Fallback to xattr (legacy data, files moved before bookmark tracking)

**Delete:**

1. Remove from database
2. Clear xattr

### Why Hybrid?

| Storage | Purpose                                                     |
| ------- | ----------------------------------------------------------- |
| SQLite  | Fast lookups, bookmark tracking for moved/renamed files     |
| xattr   | Notes visible in Finder's "Get Info", travel with files     |

### Database Schema

Location: `~/Library/Application Support/Notes/notes.db`

```sql
CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    file_path TEXT NOT NULL,
    file_bookmark BLOB,           -- macOS file bookmark (survives rename/move)
    bookmark_hash TEXT,           -- Base64 hash for bookmark lookup
    title TEXT NOT NULL DEFAULT '',
    body TEXT NOT NULL DEFAULT '',
    created_at REAL NOT NULL,
    modified_at REAL NOT NULL
);
CREATE INDEX idx_file_path ON notes(file_path);
CREATE INDEX idx_bookmark_hash ON notes(bookmark_hash);
```

The database directory is created automatically on first run. WAL mode is enabled for better performance.

---

## Key Classes

### NoteDatabase (Services/NoteDatabase.swift)

- Singleton: `NoteDatabase.shared`
- Auto-creates directory and schema on init
- Uses `INSERT OR REPLACE` (UPSERT) for saves
- Creates file bookmarks for tracking moved/renamed files
- Resolves bookmarks to find notes even after file moves

### NoteStorage (Services/NoteStorage.swift)

- Singleton: `NoteStorage.shared`
- Coordinates between database and xattr
- Public API: `saveNote()`, `getNote()`, `removeNote()`, `hasNote()`
- Uses AppleScript for xattr writes (proper Spotlight integration)

### Note (Models/Note.swift)

```swift
struct Note: Identifiable, Codable {
    let id: UUID
    var filePath: String
    var title: String
    var body: String
    var createdAt: Date
    var modifiedAt: Date
    var bookmarkData: Data?  // Stable identifier for rename/move persistence
}
```

- Encodes to Finder Comment format: `NOTES:v1\n---TITLE---\n...\n---BODY---\n...`
- Parses legacy format (plain text = body only)

### AppDelegate (AppDelegate.swift)

- Initializes database, menu bar manager, preferences
- Registers global shortcut via `ShortcutManager`
- Handles shortcut press: toggles editor (show/hide)
- Listens for `Notification.Name.openNoteEditor` from menu bar

### MenuBarManager (MenuBarManager.swift)

- Creates `NSStatusItem` with custom icon
- Builds dynamic menu based on Finder selection (single/multi)
- Caches selection on menu open (survives focus loss)
- Posts notifications to open editor
- Menu structure:
  - Context status line (disabled): "Select a file in Finder" / "Ready" / "X items selected"
  - Separator
  - Preferences… (⌘,)
  - Separator
  - Quit Notes (⌘Q)

### FinderSelectionMonitor (Services/FinderSelectionMonitor.swift)

- Gets current Finder selection via AppleScript/osascript
- Caches selection (menu bar click steals focus)
- Returns array of URLs for multi-selection

---

## Build and Run

```bash
cd Notes
swift build
.build/debug/Notes
```

Or open in terminal and run:

```bash
open .build/debug/Notes
```

For release build:

```bash
swift build -c release
.build/release/Notes
```

See `TERMINAL_COMMANDS.md` for complete build/debug commands.

---

## Editor Keyboard Shortcuts

| Shortcut | Action                    |
| -------- | ------------------------- |
| ⌘↵       | Save and close            |
| ⌘X       | Delete note (if existing) |
| ESC      | Cancel/close (new notes)  |
| ⌃⌥N      | Toggle editor (global)    |

Note: Global shortcut toggles the panel - pressing it again closes the editor.

---

## User Preferences

Stored in `UserDefaults.standard` via `AppSettings` struct:

| Key                  | Type         | Default     |
| -------------------- | ------------ | ----------- |
| `globalShortcut`     | String       | `"⌃⌥N"`     |
| `iconColor`          | String (hex) | `"#000000"` |
| `badgeColor`         | String (hex) | `"#007AFF"` |
| `launchAtLogin`      | Bool         | `false`     |
| `duplicateNoteWithFile` | Bool      | `false`     |

**Note:** `iconColor` and `badgeColor` are stored but no longer exposed in Preferences UI (will be moved to note editor later).

### Preferences Window

**Location:** Menu bar → Preferences… (⌘,)

**Features:**
- Single unified window (no tabs)
- Dark Raycast-inspired theme
- Three preference rows:
  1. **Keyboard Shortcut** - Customizable global shortcut with recorder
  2. **Launch at Login** - Toggle to start app on macOS login
  3. **Duplicate note with file** - When enabled, duplicated files keep the same note
- Footer with app version, copyright, and "Give Feedback" link
- Window sizes to fit content
- Close button only (no minimize/fullscreen)

**Window Controller:** `PreferencesWindowController.swift`
- Applies dark theme styling (`NSVisualEffectView` with `.ultraDark` material)
- Dark overlay for deeper darkness
- Rounded corners (12pt radius)

---

## Notifications (Internal)

| Name                          | Purpose                           | UserInfo                |
| ----------------------------- | --------------------------------- | ----------------------- |
| `.openNoteEditor`             | Request to open editor            | `["url": URL]`          |
| `.noteEditorWillDismiss`      | Editor about to close             | object: WindowController|

---

## Known Issues & Workarounds

### Finder Automation Permissions

- **Issue:** AppleScript cannot access Finder selection without permission
- **Symptom:** "No file selected" even when file is selected
- **Fix:** System Settings → Privacy & Security → Automation → Enable "Finder" for Terminal/Notes
- **Details:** See `FINDER_PERMISSION_ISSUE.md` and `QUICK_FIX.md`

### Notes on Move/Rename

- **Status:** Largely resolved with bookmark tracking
- File bookmarks (stored in database) track files through moves/renames
- If bookmark resolution fails, falls back to xattr read
- Cross-volume moves may still lose xattr (FAT32/exFAT limitation)

### Notes Duplicated with Files

- **Expected behavior** - xattrs are copied when duplicating files
- Not a bug, just documented behavior

---

## Common Tasks

### Adding a new preference

1. Add property to `AppSettings` struct in `Settings.swift`
2. Add key to `Keys` enum
3. Update `save()` and `load()` methods
4. Add default value in `AppSettings.defaults`
5. Add UI row in `PreferencesView.swift` using `preferenceRow()` helper
6. Add `onChange` handler to call `viewModel.saveSettings()`

### Modifying note storage

- `NoteDatabase.swift` - SQLite operations
- `NoteStorage.swift` - Coordination logic
- Both should be updated together for new fields

### Changing the editor UI

- `NoteEditorView.swift` - SwiftUI layout
- `NoteEditorWindowController.swift` - Window chrome, vibrancy, dark overlay

### Changing preferences UI

- `PreferencesView.swift` - SwiftUI layout (single unified view, no tabs)
- `PreferencesWindowController.swift` - Window styling, dark theme application
- `PreferencesViewModel.swift` - State management (no appearance properties)
- Use `preferenceRow()` helper for consistent row styling

### Adding a menu action

- `MenuBarManager.swift` - Add `@objc` action method
- Add item in `buildSingleSelectionMenu()` or `buildMultiSelectionMenu()`

---

## Files to Read First

For quick context on any task:

1. **This file** - Architecture overview
2. `NoteStorage.swift` - Storage coordination (small, key logic)
3. `NoteDatabase.swift` - Database implementation
4. `AppDelegate.swift` - App lifecycle, shortcut handling
5. `MenuBarManager.swift` - Menu bar logic

For historical context and decisions:

- `PRODUCT-DEVELOPMENT.md` - Development log with rationale

For build/debug commands:

- `TERMINAL_COMMANDS.md` - Complete command reference

---

## Testing Database

```bash
# View schema
sqlite3 ~/Library/Application\ Support/Notes/notes.db ".schema"

# List all notes
sqlite3 ~/Library/Application\ Support/Notes/notes.db "SELECT file_path, title FROM notes;"

# Clear database (for fresh testing)
rm ~/Library/Application\ Support/Notes/notes.db
```

---

## Quick Debugging

```bash
# Check if app is running
ps aux | grep Notes

# Kill running app
pkill -f "Notes"

# View app logs (real-time)
log stream --predicate 'process == "Notes"' --level debug

# Test Finder selection AppleScript
osascript -e 'tell application "Finder" to if (count of selection) > 0 then get POSIX path of (item 1 of selection as alias)'
```

---

## Recent Changes (January 2026)

### Unified Preferences Redesign

- **Menu Bar:** Removed "Send Feedback" and "About Notes" items. Menu now shows context status, Preferences, and Quit only.
- **Preferences Window:** Consolidated from 3 tabs to single unified dark-themed window.
- **New Setting:** Added "Duplicate note with file" toggle (default: false).
- **Removed:** Appearance settings (icon color, badge color) from preferences (will move to note editor later).
- **Footer:** Added version info and "Give Feedback" link to preferences window.
- **Window Behavior:** Window sizes to fit content, removed minimize/fullscreen buttons, shortcut recorder deactivates on focus loss.

### Database Migration

- Automatic migration adds `bookmark_hash` column to existing databases.
- Migration runs on app launch and is idempotent (safe to run multiple times).
- See `NoteDatabase.migrateSchema()` for implementation.

### Build System

- Fixed Info.plist warning by excluding it from Package.swift resources.
- Fixed database migration order (migration before index creation).

---

_Last Updated: January 2026_

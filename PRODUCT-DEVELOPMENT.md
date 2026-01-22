# Notes App - Product Development Log

A living document capturing the development journey, technical decisions, issues encountered, and their resolutions.

---

## Project Overview

**Notes** is a minimal macOS menu bar utility that allows users to attach plain-text notes to files and folders. The app runs as a background application (no Dock icon) and is accessible via a global keyboard shortcut or the menu bar icon.

### Tech Stack

- **Swift 5.9+** / **macOS 13.0+**
- **SwiftUI** - Note editor UI
- **AppKit** - Menu bar integration, window management
- **Extended Attributes (xattr)** - Note storage via Finder Comments
- **AppleScript** - Finder integration for selection detection and comment writing

### Core Features

- Attach notes to any file or folder
- Notes stored in Finder Comments (visible in Get Info)
- Global keyboard shortcut access
- Dark, Raycast-inspired UI
- Notes travel with files (stored as metadata)

---

## Development Timeline

### Phase 1: Initial Implementation

**Goal:** Create a functional menu bar app that can attach notes to files.

#### Completed Work

1. **Menu Bar App Architecture**
   - `LSUIElement` background app (no Dock icon)
   - Status item with custom icon
   - Dropdown menu with dynamic items

2. **Note Storage System**
   - Chose `kMDItemFinderComment` extended attribute for storage
   - Notes visible in Finder's "Get Info" panel
   - No external database required

3. **Finder Selection Monitoring**
   - AppleScript queries via `osascript` process
   - Multiple fallback scripts for compatibility
   - Selection caching to survive menu bar click focus loss

4. **Note Editor UI**
   - Borderless floating panel (Raycast-inspired)
   - Dark vibrancy effect with `NSVisualEffectView`
   - Title and body fields with placeholder text
   - Keyboard shortcuts (⌘↵ save, ⌘X delete, ESC cancel)
   - Auto-save on dismiss, auto-delete empty notes

5. **Preferences System**
   - Launch at login toggle
   - Global shortcut customization
   - Icon color customization

#### Technical Decisions (Phase 1)

**Why Finder Comments for Storage?**

- **Pros:**
  - Notes travel WITH files (attached as metadata)
  - Visible in native Finder UI (Get Info panel)
  - No external database to maintain or sync
  - Works offline, no cloud dependency
- **Cons:**
  - May not survive cross-volume moves (FAT32/exFAT)
  - Limited to text content
  - Requires proper encoding (binary plist)

**Why AppleScript for Finder Selection?**

- Most reliable way to query Finder's current selection
- Multiple script approaches handle different file types
- `osascript` process avoids NSAppleScript permission issues

---

### Phase 2: Feature Enhancements

**Goal:** Fix storage bugs, add visual indicators, improve UX.

#### Completed Work

1. **Finder Comments Storage Bug Fix**
   - **Problem:** Notes written via `setxattr` weren't appearing in Finder's Get Info
   - **Root Cause:** Binary plist was written correctly but Spotlight wasn't indexing it
   - **Solution:** Use AppleScript as primary write method (properly integrates with Spotlight), xattr as fallback
   - **Files Modified:** `NoteStorage.swift`

2. **Finder Sync Extension (Code Created)**
   - Created extension structure in `Notes/NotesFinderSync/`
   - Real-time xattr checking for badges (no registry needed)
   - Survives file moves (checks xattr at current location)
   - **Status:** Code complete, requires Xcode project setup to build
   - **Files Created:** `FinderSync.swift`, `Info.plist`, `NotesFinderSync.entitlements`

3. **Multi-Selection Support**
   - Updated `FinderSelectionMonitor` to return array of selected URLs
   - AppleScript returns delimiter-separated paths for multiple items
   - Cache system updated for multi-selection
   - **Files Modified:** `FinderSelectionMonitor.swift`

4. **Context-Aware Menu Actions**
   - Single selection: Add/Edit/Copy/Remove Note
   - Multiple selection: Bulk add/remove with counts
   - "Copy Note" action copies note content to clipboard
   - Shows "Select a file in Finder" hint when nothing selected
   - **Files Modified:** `MenuBarManager.swift`

5. **Darker UI Theme**
   - Changed `NSVisualEffectView` material from `.hudWindow` to `.ultraDark`
   - Added 25% black overlay for deeper darkness
   - Adjusted text opacities for better contrast on darker background
   - **Files Modified:** `NoteEditorWindowController.swift`, `NoteEditorView.swift`

#### Technical Decisions (Phase 2)

**Why AppleScript for Writing Comments?**

- Direct `setxattr` writes weren't being picked up by Spotlight
- AppleScript `set comment of` properly notifies Finder/Spotlight
- Fallback to xattr + `mdimport` if AppleScript fails (permissions)

**Why Real-Time xattr Checking for Finder Sync?**

- No registry/database to maintain
- Survives file moves automatically
- Always accurate (reads from actual file)
- Trade-off: Slightly slower for large directories

---

## Known Issues and Investigations

### Issue: Notes Lost When Moving or Renaming Files

**Status:** PARTIALLY FIXED - Still Under Investigation

**Symptoms:**

- User moves a file/folder with a note attached
- Note appears to be gone from the moved file
- Same issue occurs when renaming files/folders

**Hypothesis:**
Looking at `NoteStorage.swift` lines 56-68, there's a potential bug:

```swift
private func readFinderComment(for url: URL) -> String? {
    guard let mdItem = MDItemCreateWithURL(nil, url as CFURL) else {
        return nil  // BUG: Never tries xattr fallback!
    }
    // ...
    return readXattr(for: url)
}
```

When `MDItemCreateWithURL` returns `nil` (happens for recently moved files not yet indexed by Spotlight), we return `nil` immediately without trying the direct xattr read.

**Investigation Plan:**

1. Create test file with note
2. Move file to new location
3. Check if xattr still exists (should)
4. Check if Spotlight returns nil (likely)
5. Determine if this is the root cause

**Investigation Results (January 2026):**

Ran `test_move_behavior.sh` to test file move behavior:

| Test                                   | Result                |
| -------------------------------------- | --------------------- |
| xattr preserved after move             | **YES**               |
| Spotlight reads immediately after move | **NO** (returns null) |
| Spotlight reads after 3 second delay   | **YES**               |

**Key Findings:**

1. The extended attribute (xattr) **IS preserved** when moving files within the same volume
2. Spotlight indexing has **significant lag** - returns `(null)` immediately after move
3. Spotlight eventually indexes the moved file (within ~3 seconds)
4. Interestingly, Spotlight also returned `(null)` for files in `/tmp` even BEFORE moving

**Root Cause Confirmed:**
The bug is in `NoteStorage.readFinderComment()`:

```swift
guard let mdItem = MDItemCreateWithURL(nil, url as CFURL) else {
    return nil  // BUG: Never tries xattr fallback!
}
```

When `MDItemCreateWithURL` returns `nil` (which happens for:

- Recently moved files
- Files in non-indexed locations like `/tmp`
- Files not yet indexed by Spotlight)

...we return `nil` immediately **without trying the xattr fallback**.

**Fix Attempted (Partial):**
Changed the read logic in `NoteStorage.readFinderComment()` to try xattr when MDItem fails:

```swift
private func readFinderComment(for url: URL) -> String? {
    // Try MDItem first (faster for indexed files)
    if let mdItem = MDItemCreateWithURL(nil, url as CFURL),
       let comment = MDItemCopyAttribute(mdItem, kMDItemFinderComment) as? String,
       !comment.isEmpty {
        return comment
    }

    // Fallback: Always try xattr (works for moved/unindexed files)
    return readXattr(for: url)
}
```

**File Modified:** `Notes/Sources/Services/NoteStorage.swift`

**Issue Persists:**
After applying the above fix, testing revealed that notes are still being lost when:

- Moving files/folders to a different location
- Renaming files/folders

**Further Investigation Needed:**

- Is the xattr actually being preserved by macOS during moves/renames?
- Is there a difference between Finder moves vs terminal `mv` command?
- Could this be related to how AppleScript sets the Finder comment vs direct xattr?
- Need to verify xattr exists on moved file using `xattr -l` command
- May need to explore alternative storage approaches if xattr is unreliable

---

### Issue: Notes Duplicated with Files

**Status:** Deferred (Documented as Expected Behavior)

**Symptoms:**

- User duplicates a file in Finder
- The duplicate also has the note attached

**Explanation:**
This is expected macOS behavior. When duplicating a file:

- All extended attributes are copied
- Finder Comments (our note storage) are extended attributes
- Therefore, notes are duplicated

**Decision:**

- Document as expected behavior
- Consider adding "Copy Note to..." feature for intentional copying
- May revisit if users find it confusing

---

## Architecture Notes

### Data Flow: Saving a Note

```
User edits note in NoteEditorView
        ↓
NoteEditorViewModel.buildNote()
        ↓
NoteStorage.saveNote(note, to: url)
        ↓
writeFinderComment() → Try AppleScript first
        ↓                    ↓ (if fails)
AppleScript sets         writeViaXattr() + mdimport
Finder comment                ↓
        ↓               Spotlight reindexes
Note visible in
Get Info panel
```

### Data Flow: Reading a Note

```
User clicks menu bar / presses shortcut
        ↓
FinderSelectionMonitor.getCachedOrCurrentSelections()
        ↓
AppleScript queries Finder selection
        ↓
MenuBarManager.buildMenuItems()
        ↓
NoteStorage.hasNote(for: url)
        ↓
readFinderComment() → Try MDItem (Spotlight) first
        ↓                    ↓ (if nil/empty)
Return comment           readXattr() directly
        ↓
Display Add/Edit/Remove options
```

---

## File Structure

```
notes/
├── Notes/
│   ├── Package.swift
│   ├── Sources/
│   │   ├── NotesApp.swift          # App entry point
│   │   ├── AppDelegate.swift       # Lifecycle, window management
│   │   ├── MenuBarManager.swift    # Menu bar icon and dropdown
│   │   ├── Models/
│   │   │   ├── Note.swift          # Note data model with encoding
│   │   │   └── Settings.swift      # App preferences
│   │   ├── Services/
│   │   │   ├── NoteStorage.swift   # xattr/AppleScript storage
│   │   │   ├── FinderSelectionMonitor.swift
│   │   │   ├── ShortcutManager.swift
│   │   │   └── LaunchAtLoginManager.swift
│   │   ├── Views/
│   │   │   ├── NoteEditorView.swift
│   │   │   ├── NoteEditorViewModel.swift
│   │   │   ├── NoteEditorWindowController.swift
│   │   │   ├── PreferencesView.swift
│   │   │   └── ...
│   │   └── Resources/
│   │       ├── Assets.xcassets
│   │       └── Info.plist
│   └── NotesFinderSync/            # Finder extension (not yet built)
│       ├── FinderSync.swift
│       ├── Info.plist
│       └── Assets.xcassets
├── PRODUCT-DEVELOPMENT.md          # This file
├── README.md
└── TERMINAL_COMMANDS.md
```

---

## Lessons Learned

1. **Spotlight Integration is Tricky**
   - Writing xattr directly doesn't notify Spotlight
   - AppleScript is more reliable for Finder Comment integration
   - `mdimport` can force reindexing as a fallback

2. **Finder Selection Requires Caching**
   - Clicking menu bar steals focus from Finder
   - Selection must be cached before menu opens
   - Multiple AppleScript approaches needed for edge cases

3. **Finder Sync Extensions Need Xcode**
   - Swift Package Manager doesn't support app extensions
   - Must create proper Xcode project with embedded extension
   - Extension code can be written in advance

4. **Dark UI Needs Careful Color Tuning**
   - `NSVisualEffectView` materials have different darkness levels
   - Additional overlay can deepen the effect
   - Text opacity needs adjustment for contrast

---

## Future Considerations

- [ ] **HIGH PRIORITY:** Resolve notes lost on move/rename issue
- [ ] Finder Sync Extension build integration
- [ ] Consider alternative storage approaches if xattr proves unreliable:
  - SQLite database with file path tracking
  - Sidecar files (`.filename.note`)
  - Hybrid approach (xattr + backup database)
- [ ] Rich text or Markdown support?
- [ ] Search/browse all notes feature?
- [ ] iCloud sync for notes?

---

## Phase 3: Unified Preferences Redesign (January 2026)

**Goal:** Consolidate preferences into a single, dark-themed window matching the Raycast-inspired editor UI.

### Completed Work

1. **Menu Bar Simplification**
   - Removed "Send Feedback" and "About Notes" menu items
   - Updated menu structure with context-aware status line:
     - "Select a file in Finder" when nothing selected
     - "Ready" for single selection
     - "1 item selected" or "X items selected" for multi-selection
   - Clean menu structure: context status → separator → Preferences… (⌘,) → separator → Quit Notes (⌘Q)
   - **Files Modified:** `MenuBarManager.swift`

2. **Unified Preferences Window**
   - Removed tab-based interface (General, Shortcuts, Appearance tabs)
   - Created single unified preferences window with dark theme
   - Window title: "Notes Preferences"
   - Removed appearance settings (icon color, badge color) - moving to note UI later
   - **Files Modified:** `PreferencesView.swift`, `PreferencesWindowController.swift`, `PreferencesViewModel.swift`

3. **Preferences Content**
   - **Keyboard Shortcut:** Shortcut recorder with helper text "Press the shortcut to show/hide the note editor."
   - **Launch at Login:** Toggle switch
   - **Duplicate note with file:** New toggle setting (default: false) with helper text explaining behavior
   - **Footer:** App icon, version info (from Info.plist), copyright, and "Give Feedback" link (replaces menu item)
   - **Files Modified:** `Settings.swift` (added `duplicateNoteWithFile`), `PreferencesView.swift`

4. **Dark Theme Styling**
   - Applied `NSVisualEffectView` with `.ultraDark` material
   - Added dark overlay (25% black) for deeper darkness
   - Rounded corners (12pt radius)
   - White text with opacity variations (0.9 for labels, 0.5-0.7 for secondary text)
   - Rounded preference rows with subtle background (`Color.white.opacity(0.05)`)
   - Matches `NoteEditorWindowController` styling
   - **Files Modified:** `PreferencesWindowController.swift`, `PreferencesView.swift`, `ShortcutRecorderView.swift`

5. **Window Behavior Improvements**
   - Window sizes to fit content (removed fixed height)
   - Removed minimize and fullscreen buttons (close button only)
   - Shortcut recorder deactivates when window loses focus
   - **Files Modified:** `PreferencesWindowController.swift`, `PreferencesView.swift`, `ShortcutRecorderView.swift`

6. **Build System Fixes**
   - Fixed Info.plist warning by excluding it from resources in Package.swift
   - Fixed database migration order (migration runs before index creation)
   - Added migration logging for debugging
   - **Files Modified:** `Package.swift`, `NoteDatabase.swift`

### Technical Decisions (Phase 3)

**Why Remove Appearance Settings from Preferences?**

- Appearance customization (icon color, badge color) will be moved to the note editor UI later
- Simplifies preferences to core functionality
- Reduces maintenance burden
- Users can customize appearance where they interact with notes

**Why Single Unified Window Instead of Tabs?**

- Better UX for small number of settings (only 3 preferences)
- Matches modern app design patterns (Raycast, etc.)
- Dark theme works better as single cohesive view
- Easier to maintain than multiple tab views

**Why Move Feedback and About to Footer?**

- Reduces menu clutter
- About info (version, copyright) is rarely accessed
- Feedback link in preferences is more discoverable for users who want to provide feedback
- Keeps menu bar focused on core actions

**Why Window Sizing to Fit Content?**

- More elegant than fixed-size window
- Adapts if preferences are added/removed
- Better use of screen space
- Professional appearance

### Code Quality Improvements

- Removed unused appearance-related code from `PreferencesViewModel`
- Simplified `resetToDefaults()` method
- Better separation of concerns (window controller handles styling, view handles layout)
- Improved error handling in database migration

### Migration Notes

**Database Migration:**
- Existing databases created before `bookmark_hash` column was added will be automatically migrated
- Migration runs on app launch and adds missing column if needed
- Migration is idempotent (safe to run multiple times)

**User Settings:**
- `duplicateNoteWithFile` setting added with default value `false`
- Existing users will get default value on first launch after update
- No data loss - all existing preferences preserved

---

_Last Updated: January 2026_

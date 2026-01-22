# Quick Fix for Finder Selection

## The Problem
The app shows "No file selected" even when you have a file selected in Finder. This is a **macOS security feature** - apps need explicit permission to control other apps via AppleScript.

## Quick Test
Run this command in Terminal (with a file selected in Finder):
```bash
osascript -e 'tell application "Finder" to if (count of selection) > 0 then get POSIX path of (item 1 of selection as alias)'
```

**If it returns a file path:** Permissions work in Terminal
**If it returns empty/error:** Permissions needed

## The Fix

### Option 1: Use the "Change..." Button (Works Now!)
1. Press ⌃⌥N to open note editor
2. Click **"Change..."** button
3. Select your file
4. Type note and save

### Option 2: Use Menu Bar (Works Now!)
1. Select file in Finder
2. Click menu bar icon
3. Click "Add Note"
4. Editor opens with file already selected

### Option 3: Grant Automation Permission
The AppleScript needs permission to access Finder. Since we're running from a Swift build (not a proper .app), the permission system is tricky.

**Try this:**
1. Run the app from Terminal: `cd Notes && .build/debug/Notes`
2. Press ⌃⌥N
3. If macOS shows a permission dialog, click "OK"
4. Check System Settings → Privacy & Security → Automation
5. Look for "Notes" or "Terminal" and enable "Finder"

## Why This Happens
Swift Package Manager builds don't create proper `.app` bundles with bundle identifiers. macOS doesn't know how to track permissions for these executables.

**Long-term solution:** Convert to Xcode project and build as proper `.app` bundle.

## Current Workaround
The app now works even without Finder permissions:
- ✅ Global shortcut opens editor
- ✅ "Change..." button lets you browse for files
- ✅ Menu bar dropdown works when you click it
- ✅ Notes save and load properly

The only thing that doesn't work is **auto-detecting** the Finder selection when you press the shortcut. Everything else is fully functional!

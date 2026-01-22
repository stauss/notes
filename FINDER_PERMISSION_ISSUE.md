# Finder Selection Permission Issue

## Problem
The app shows "ℹ️ No file selected in Finder" even when a file is selected. This is because AppleScript cannot access Finder without explicit permission.

## Root Cause
macOS requires **Automation permissions** for apps to control other apps via AppleScript. The Notes app needs permission to control Finder.

## Solution Options

### Option 1: Grant Automation Permission (Recommended)

1. **System Settings → Privacy & Security → Automation**
2. Look for one of these:
   - "Notes" (if the app appears)
   - "osascript" (the AppleScript runner)
   - The terminal app you're using
3. Enable the checkbox for **"Finder"**

**Note:** The app might not appear in the list until it first tries to access Finder. You may need to:
- Run the app
- Try to use the shortcut
- Check if a permission dialog appears
- If dialog appears, click "OK"

### Option 2: Alternative - Use Frontmost Finder Window

Instead of getting the selected item, we can get the frontmost Finder window's location. This is less restrictive but still useful.

### Option 3: Manual File Selection

Add a menu item "Add Note for..." that opens a file picker, bypassing Finder entirely.

## Testing Permission

Run this command in Terminal (with a file selected in Finder):
```bash
osascript -e 'tell application "Finder" to if (count of selection) > 0 then get POSIX path of (item 1 of selection as alias)'
```

**Expected Results:**
- ✅ **Success**: Prints the file path (e.g., `/Users/caleb/Desktop/file.png`)
- ❌ **Permission Denied**: Shows error or empty result
- ❓ **Permission Dialog**: macOS asks for permission - click "OK"

## Why This Happens

When running from Swift Package Manager builds (`.build/debug/Notes`), the executable doesn't have a proper app bundle identity. macOS treats it as a generic executable, making permissions tricky.

**Solutions:**
1. Grant permission to Terminal/your shell
2. Build as proper `.app` bundle (requires Xcode project)
3. Use alternative methods that don't need Finder access

## Temporary Workaround

For now, we can:
1. Add a "Browse..." button in the note editor to manually select files
2. Use the menu bar dropdown (which already works when you click it)
3. Show the note editor with an empty path, let user browse

This way the app is still functional while we work on Finder permissions.

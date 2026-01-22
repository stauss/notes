# Notes Finder Sync Extension

This Finder Sync Extension displays badge icons on files and folders that have notes attached.

## Features

- **Badge Icons**: Shows a small note badge on files/folders with notes
- **Real-time Detection**: Checks xattr directly (survives file moves)
- **Context Menu**: Adds "Add Note" option to right-click menu
- **Toolbar Button**: Optional toolbar integration in Finder

## Build Requirements

Finder Sync Extensions require an **Xcode project** (not Swift Package Manager) because:

1. Extensions must be embedded within the main app bundle
2. Code signing requirements for extensions
3. Proper entitlements configuration

### Setup Steps

1. **Create Xcode Project** (if not already):
   ```bash
   # Convert SPM to Xcode project or create new
   swift package generate-xcodeproj
   ```

2. **Add Extension Target**:
   - In Xcode: File → New → Target
   - Choose "Finder Sync Extension"
   - Name it "NotesFinderSync"
   - Set bundle identifier: `com.yourcompany.Notes.FinderSync`

3. **Configure Extension**:
   - Copy `FinderSync.swift` to the new target
   - Copy `Info.plist` settings to the target's Info.plist
   - Add entitlements from `NotesFinderSync.entitlements`

4. **Add Badge Assets**:
   - Add `NoteBadge.png` (16x16) and `NoteBadge@2x.png` (32x32) to Assets
   - The extension includes a programmatic fallback if images are missing

5. **Build & Run**:
   - Build the main app (extension is embedded automatically)
   - The extension appears in System Settings → Privacy & Security → Extensions → Finder

## Badge Image Requirements

- **Size**: 16x16 points (16px @1x, 32px @2x)
- **Format**: PNG with transparency
- **Design**: Small, recognizable note icon
- **Colors**: Use system colors for consistency

## Testing

1. Build and run the main Notes app
2. Enable the extension in System Settings → Extensions → Finder
3. Add a note to a file using the Notes app
4. The badge should appear on the file in Finder

## Troubleshooting

- **Badge not appearing**: Check that extension is enabled in System Settings
- **Extension not loading**: Verify code signing and entitlements
- **Permission issues**: Finder Sync extensions may need Full Disk Access for some directories

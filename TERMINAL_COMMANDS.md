# Notes App - Terminal Commands Reference

## Quick Start

### Build and Run (One Command)
```bash
cd /Users/caleb/Desktop/_Development/notes/Notes && swift build && open .build/debug/Notes
```

---

## Navigation

### Go to Project Directory
```bash
cd /Users/caleb/Desktop/_Development/notes/Notes
```

### Go to Root Directory
```bash
cd /Users/caleb/Desktop/_Development/notes
```

---

## Building

### Build Debug Version
```bash
swift build
```

### Build Release Version
```bash
swift build -c release
```

### Clean Build
```bash
swift package clean
```

### Clean and Rebuild
```bash
swift package clean && swift build
```

---

## Running

### Run Debug Build
```bash
open .build/debug/Notes
```

### Run Release Build
```bash
open .build/release/Notes
```

### Run with Swift (Alternative)
```bash
swift run
```

---

## Development Workflow

### Build, Run, and Watch Logs
```bash
swift build && open .build/debug/Notes && tail -f /var/log/system.log | grep Notes
```

### Quick Rebuild and Run
```bash
swift build && open .build/debug/Notes
```

### Kill Running App and Restart
```bash
pkill -f "Notes" && swift build && open .build/debug/Notes
```

---

## Project Management

### View Project Structure
```bash
tree -L 3 -I '.build'
```

### List Source Files
```bash
find Sources -name "*.swift"
```

### Count Lines of Code
```bash
find Sources -name "*.swift" | xargs wc -l
```

### View Package Dependencies
```bash
swift package show-dependencies
```

---

## Debugging

### Check if App is Running
```bash
ps aux | grep Notes
```

### Kill Running App
```bash
pkill -f "Notes"
```

### View App Logs (Console.app alternative)
```bash
log stream --predicate 'process == "Notes"' --level debug
```

### Check Build Output Size
```bash
ls -lh .build/debug/Notes
```

---

## Git Commands

### Check Status
```bash
git status
```

### Add All Changes
```bash
git add .
```

### Commit Changes
```bash
git commit -m "Your commit message"
```

### Push to Remote
```bash
git push
```

### Quick Commit and Push
```bash
git add . && git commit -m "Update" && git push
```

---

## Opening in Xcode

### Open Package in Xcode
```bash
open Package.swift
```

### Generate Xcode Project (if needed)
```bash
swift package generate-xcodeproj
open Notes.xcodeproj
```

---

## Useful Shortcuts

### Build and Run (Recommended)
```bash
cd /Users/caleb/Desktop/_Development/notes/Notes
swift build && open .build/debug/Notes
```

### Full Clean Rebuild
```bash
cd /Users/caleb/Desktop/_Development/notes/Notes
swift package clean
swift build
open .build/debug/Notes
```

### Check Build Time
```bash
time swift build
```

---

## Troubleshooting

### Clear Derived Data
```bash
rm -rf .build
swift build
```

### Reset Package Cache
```bash
swift package reset
swift package resolve
swift build
```

### Check Swift Version
```bash
swift --version
```

### Check Xcode Version
```bash
xcodebuild -version
```

### Verify File Permissions
```bash
ls -la .build/debug/Notes
```

---

## Notes Storage

### View Saved Notes
```bash
cat ~/Library/Application\ Support/Notes/notes.json | python3 -m json.tool
```

### Check Notes Directory
```bash
ls -la ~/Library/Application\ Support/Notes/
```

### Delete All Notes (Reset)
```bash
rm ~/Library/Application\ Support/Notes/notes.json
```

---

## Aliases (Add to ~/.zshrc)

Add these to your `~/.zshrc` for quick access:

```bash
# Notes app aliases
alias notes-cd='cd /Users/caleb/Desktop/_Development/notes/Notes'
alias notes-build='cd /Users/caleb/Desktop/_Development/notes/Notes && swift build'
alias notes-run='cd /Users/caleb/Desktop/_Development/notes/Notes && swift build && open .build/debug/Notes'
alias notes-clean='cd /Users/caleb/Desktop/_Development/notes/Notes && swift package clean'
alias notes-kill='pkill -f "Notes"'
alias notes-restart='pkill -f "Notes" && cd /Users/caleb/Desktop/_Development/notes/Notes && swift build && open .build/debug/Notes'
```

After adding, reload your shell:
```bash
source ~/.zshrc
```

Then you can use:
- `notes-run` - Build and run
- `notes-kill` - Stop the app
- `notes-restart` - Kill, rebuild, and run
- `notes-clean` - Clean build artifacts

---

## Common Issues

### "Permission Denied" Error
```bash
chmod +x .build/debug/Notes
```

### "App is Damaged" Error
```bash
xattr -cr .build/debug/Notes.app
```

### Port Already in Use / App Won't Start
```bash
pkill -f "Notes"
# Wait 2 seconds
sleep 2
open .build/debug/Notes
```

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Build | `swift build` |
| Run | `open .build/debug/Notes` |
| Build + Run | `swift build && open .build/debug/Notes` |
| Clean | `swift package clean` |
| Kill App | `pkill -f "Notes"` |
| Open in Xcode | `open Package.swift` |
| View Logs | `log stream --predicate 'process == "Notes"'` |
| Check Status | `ps aux \| grep Notes` |

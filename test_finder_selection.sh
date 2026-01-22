#!/bin/bash

# Test Finder Selection Script
# This helps diagnose if AppleScript can access Finder selection

echo "🔍 Testing Finder Selection Detection..."
echo ""

# Test 1: Check if Finder is running
echo "1️⃣ Checking if Finder is running..."
if pgrep -x "Finder" > /dev/null; then
    echo "   ✅ Finder is running"
else
    echo "   ❌ Finder is not running"
    exit 1
fi

echo ""

# Test 2: Try to get Finder selection
echo "2️⃣ Attempting to get Finder selection..."
echo "   (Make sure you have a file selected in Finder!)"
echo ""

RESULT=$(osascript -e 'tell application "Finder" to if (count of selection) > 0 then get POSIX path of (item 1 of selection as alias)' 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ] && [ -n "$RESULT" ]; then
    echo "   ✅ Successfully detected selection:"
    echo "   📁 $RESULT"
else
    echo "   ❌ Failed to detect selection"
    echo "   Error: $RESULT"
    echo ""
    echo "💡 Possible solutions:"
    echo "   1. Make sure a file or folder is selected in Finder"
    echo "   2. Grant Automation permissions:"
    echo "      • Open System Settings"
    echo "      • Go to Privacy & Security → Automation"
    echo "      • Find 'Terminal' or 'Notes' in the list"
    echo "      • Enable access to 'Finder'"
    echo ""
    echo "   3. Try running this command manually:"
    echo "      osascript -e 'tell application \"Finder\" to get selection'"
fi

echo ""
echo "3️⃣ Checking Automation permissions..."
echo "   If you see a permission dialog, click 'OK' to grant access"
echo ""

# This will trigger permission request if not granted
osascript -e 'tell application "System Events" to get name of processes' > /dev/null 2>&1

echo "✅ Test complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Select a file in Finder"
echo "   2. Run the Notes app"
echo "   3. Press Control+Option+N"
echo "   4. Check console output for '✅ Found selected file:' message"

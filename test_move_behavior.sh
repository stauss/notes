#!/bin/bash
# Test script to investigate note behavior on file moves
# This helps diagnose the "notes lost when moving files" issue
#
# Tests:
# 1. Whether xattr survives file moves
# 2. Whether Spotlight (MDItem) can read moved files immediately
# 3. How long Spotlight takes to reindex

set -e

echo "======================================"
echo "Notes Move Behavior Investigation"
echo "======================================"
echo ""

TEST_FILE="/tmp/test_note_file_$$_$(date +%s).txt"
MOVED_FILE="$HOME/Desktop/moved_test_file_$$.txt"

cleanup() {
    rm -f "$TEST_FILE" "$MOVED_FILE" 2>/dev/null || true
}
trap cleanup EXIT

echo "Test file: $TEST_FILE"
echo "Move destination: $MOVED_FILE"
echo ""

# Step 1: Create test file
echo "STEP 1: Creating test file..."
echo "test content for move investigation" > "$TEST_FILE"
echo "   ✓ Created: $TEST_FILE"
echo ""

# Step 2: Set Finder comment via AppleScript (same as our app does)
echo "STEP 2: Setting Finder comment via AppleScript..."
osascript -e "tell application \"Finder\" to set comment of (POSIX file \"$TEST_FILE\" as alias) to \"NOTES:v1
---TITLE---
Test Note Title
---BODY---
This is a test note body for move investigation.\""
echo "   ✓ Comment set"
echo ""

# Step 3: Verify comment was set
echo "STEP 3: Verifying comment before move..."
echo ""
echo "   --- xattr output ---"
xattr -l "$TEST_FILE" 2>/dev/null | head -10 || echo "   (no xattr found)"
echo ""
echo "   --- Spotlight (mdls) output ---"
mdls -name kMDItemFinderComment "$TEST_FILE"
echo ""

# Step 4: Move the file
echo "STEP 4: Moving file to Desktop..."
mv "$TEST_FILE" "$MOVED_FILE"
echo "   ✓ Moved to: $MOVED_FILE"
echo ""

# Step 5: Check immediately after move
echo "STEP 5: Checking IMMEDIATELY after move..."
echo ""
echo "   --- xattr output (should still exist) ---"
XATTR_OUTPUT=$(xattr -l "$MOVED_FILE" 2>/dev/null | head -10 || echo "(no xattr)")
echo "$XATTR_OUTPUT"
echo ""
echo "   --- Spotlight (mdls) output (may be nil) ---"
MDLS_IMMEDIATE=$(mdls -name kMDItemFinderComment "$MOVED_FILE" 2>/dev/null)
echo "$MDLS_IMMEDIATE"
echo ""

# Check if xattr exists
if echo "$XATTR_OUTPUT" | grep -q "kMDItemFinderComment"; then
    echo "   ✓ XATTR PRESERVED after move"
    XATTR_PRESERVED="YES"
else
    echo "   ✗ XATTR LOST after move!"
    XATTR_PRESERVED="NO"
fi

# Check if Spotlight can read it
if echo "$MDLS_IMMEDIATE" | grep -q "NOTES:v1"; then
    echo "   ✓ Spotlight can read immediately"
    SPOTLIGHT_IMMEDIATE="YES"
elif echo "$MDLS_IMMEDIATE" | grep -q "(null)"; then
    echo "   ✗ Spotlight returns (null) - not indexed yet"
    SPOTLIGHT_IMMEDIATE="NO"
else
    echo "   ? Spotlight returned unexpected value"
    SPOTLIGHT_IMMEDIATE="UNKNOWN"
fi
echo ""

# Step 6: Wait and check again
echo "STEP 6: Waiting 3 seconds for Spotlight to index..."
sleep 3
echo ""

echo "STEP 7: Checking again after 3 second delay..."
echo ""
echo "   --- Spotlight (mdls) output ---"
MDLS_DELAYED=$(mdls -name kMDItemFinderComment "$MOVED_FILE" 2>/dev/null)
echo "$MDLS_DELAYED"
echo ""

if echo "$MDLS_DELAYED" | grep -q "NOTES:v1"; then
    echo "   ✓ Spotlight can read after delay"
    SPOTLIGHT_DELAYED="YES"
elif echo "$MDLS_DELAYED" | grep -q "(null)"; then
    echo "   ✗ Spotlight still returns (null)"
    SPOTLIGHT_DELAYED="NO"
else
    SPOTLIGHT_DELAYED="UNKNOWN"
fi
echo ""

# Step 8: Try reading xattr directly (like our fallback code)
echo "STEP 8: Reading xattr directly via Python (simulating our fallback)..."
python3 << 'PYEOF'
import subprocess
import plistlib
import sys

moved_file = sys.argv[1] if len(sys.argv) > 1 else "$MOVED_FILE"

# Read xattr
result = subprocess.run(
    ['xattr', '-px', 'com.apple.metadata:kMDItemFinderComment', moved_file],
    capture_output=True, text=True
)

if result.returncode == 0:
    # Parse hex output
    hex_str = result.stdout.replace(' ', '').replace('\n', '')
    data = bytes.fromhex(hex_str)
    # Decode plist
    try:
        comment = plistlib.loads(data)
        print(f"   ✓ Direct xattr read successful!")
        print(f"   Content preview: {comment[:50]}...")
    except Exception as e:
        print(f"   ✗ Failed to decode plist: {e}")
else:
    print(f"   ✗ xattr read failed: {result.stderr}")
PYEOF
echo ""

# Summary
echo "======================================"
echo "SUMMARY"
echo "======================================"
echo ""
echo "xattr preserved after move:     $XATTR_PRESERVED"
echo "Spotlight reads immediately:    $SPOTLIGHT_IMMEDIATE"
echo "Spotlight reads after 3s:       $SPOTLIGHT_DELAYED"
echo ""

if [ "$XATTR_PRESERVED" = "YES" ] && [ "$SPOTLIGHT_IMMEDIATE" = "NO" ]; then
    echo "DIAGNOSIS: The xattr is preserved, but Spotlight has indexing lag."
    echo ""
    echo "ROOT CAUSE CONFIRMED:"
    echo "  Our code uses MDItemCreateWithURL first, which returns nil for"
    echo "  recently moved files. We should try xattr FIRST or as a proper"
    echo "  fallback when MDItem fails."
    echo ""
    echo "RECOMMENDED FIX:"
    echo "  In NoteStorage.readFinderComment(), change the logic to:"
    echo "  1. Try xattr first (always works)"
    echo "  2. Fall back to MDItem for cache benefit"
    echo "  OR"
    echo "  1. Try MDItem first"
    echo "  2. If MDItem returns nil, try xattr (current code doesn't do this!)"
fi

echo ""
echo "Cleanup: Removing test file..."
# cleanup happens via trap

echo "Done!"

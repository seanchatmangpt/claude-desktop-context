#!/bin/bash
# Script to test MCP with proper accessibility setup

echo "=== CLAUDE MCP KEYSTROKE TEST ==="
echo ""

# Check if we have accessibility permissions
if ! osascript -e 'tell application "System Events" to keystroke "test"' 2>/dev/null; then
    echo "❌ ERROR: Terminal needs accessibility permissions!"
    echo ""
    echo "To fix this:"
    echo "1. Open System Settings > Privacy & Security > Accessibility"
    echo "2. Add Terminal (or iTerm2) to the allowed apps"
    echo "3. Toggle it ON"
    echo ""
    echo "Alternative: Run this AppleScript from Script Editor instead:"
    echo "   /Users/sac/claude-desktop-context/scripts/test-mcp-keystrokes.scpt"
    exit 1
fi

echo "✅ Accessibility permissions OK!"
echo ""
echo "Running keystroke test..."

# Now run the actual test
osascript /Users/sac/claude-desktop-context/scripts/test-mcp-keystrokes.scpt
#!/bin/bash
# Test using AppleScript to create a visible Terminal session

# Create test file
TEST_FILE="/tmp/mcp_visible_test_$(date +%s).txt"
echo "MCP Test Content - $(date)" > "$TEST_FILE"

# Use AppleScript to open Terminal and run commands visibly
osascript -e '
tell application "Terminal"
    activate
    
    -- Create new window
    set newWindow to do script ""
    delay 1
    
    -- Make it visible and in front
    set frontmost to true
    
    -- Run Claude
    do script "claude --dangerously-skip-permissions" in newWindow
    delay 3
    
    -- Type slowly so user can see
    do script "Read the file '"$TEST_FILE"' using desktop-commander" in newWindow
    
    -- Show notification
    display notification "Check the Terminal window to see if Claude can read the file" with title "MCP Test Running"
end tell
'

echo ""
echo "=== MCP TEST LAUNCHED ==="
echo "A Terminal window should now be open with Claude running."
echo "Watch to see if Claude can read the test file: $TEST_FILE"
echo ""
echo "If Claude reads the file content, MCP is working!"
echo "If Claude says it can't access files, MCP is not connected."
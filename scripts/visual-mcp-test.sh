#!/bin/bash
# Visual MCP test with clear instructions

echo "=== LAUNCHING VISUAL MCP TEST ==="
echo ""

# Create test file with clear content
TEST_FILE="/tmp/MCP_TEST_FILE.txt"
cat > "$TEST_FILE" << EOF
🎉 SUCCESS! 🎉

If you can see this message, then:
✅ MCP is WORKING!
✅ Desktop Commander is CONNECTED!
✅ Claude can access your file system!

This file was created at: $(date)
EOF

echo "Created test file: $TEST_FILE"
echo ""

# Open Terminal with Claude and instructions
osascript <<'APPLESCRIPT'
tell application "Terminal"
    activate
    
    -- Create new window
    set newWindow to do script ""
    
    -- Clear and show instructions
    do script "clear" in newWindow
    do script "echo '=== CLAUDE MCP TEST INSTRUCTIONS ==='" in newWindow
    do script "echo ''" in newWindow
    do script "echo '1. Claude will start in a moment...'" in newWindow
    do script "echo '2. You may see \"INSERT\" mode - press ESC if needed'" in newWindow
    do script "echo '3. Type this command:'" in newWindow
    do script "echo '   Read /tmp/MCP_TEST_FILE.txt'" in newWindow
    do script "echo ''" in newWindow
    do script "echo '4. If Claude shows the success message, MCP is working!'" in newWindow
    do script "echo '5. If Claude asks for approval, type: yes'" in newWindow
    do script "echo ''" in newWindow
    do script "echo 'Starting Claude in 3 seconds...'" in newWindow
    
    delay 3
    
    -- Start Claude
    do script "claude --dangerously-skip-permissions" in newWindow
    
    -- Show notification
    display notification "Type: Read /tmp/MCP_TEST_FILE.txt" with title "Claude MCP Test" subtitle "Check if Claude can read the file"
end tell
APPLESCRIPT

echo "WHAT TO DO NOW:"
echo "==============="
echo "1. A Terminal window just opened with Claude"
echo "2. Type: Read /tmp/MCP_TEST_FILE.txt"
echo "3. If you see the success message, MCP is working!"
echo ""
echo "The test file contains a clear success message."
echo "If Claude can read it, your MCP integration is confirmed!"
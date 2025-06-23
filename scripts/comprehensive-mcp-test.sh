#!/bin/bash
# Comprehensive Claude MCP test with different approaches

echo "=== COMPREHENSIVE CLAUDE MCP TEST ==="
echo ""

# First, let's check what Claude thinks about MCP
echo "1. Testing Claude's awareness of MCP servers..."
claude --dangerously-skip-permissions --print "What MCP servers do you have access to?" 2>&1 | tee /tmp/claude_mcp_awareness.txt &
CLAUDE_PID=$!
sleep 10
kill $CLAUDE_PID 2>/dev/null

echo ""
echo "Claude's response about MCP servers:"
cat /tmp/claude_mcp_awareness.txt 2>/dev/null || echo "No response captured"
echo ""

# Check if Desktop Commander responds to MCP protocol
echo "2. Testing Desktop Commander MCP server directly..."
DC_PATH="/Users/sac/.npm/_npx/4b4c857f6efdfb61/node_modules/.bin/desktop-commander"

# Send a proper MCP request
echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' | timeout 3 "$DC_PATH" 2>&1 | grep -A5 -B5 "list_directory\|read_file" && echo "✅ Desktop Commander MCP server is working!" || echo "❌ No tools found"

echo ""
echo "3. Key findings:"
echo "   - Desktop Commander IS registered: $(claude mcp list | grep -c desktop-commander) instance(s)"
echo "   - Desktop Commander path: $DC_PATH"
echo "   - Desktop Commander executable: $([ -x "$DC_PATH" ] && echo "✅ Yes" || echo "❌ No")"
echo ""

# Create a visual test AppleScript
echo "4. Launching visual test in new Terminal window..."
osascript <<'EOF'
tell application "Terminal"
    activate
    do script "echo '=== VISUAL MCP TEST ===' && echo 'Watch this window to see if Claude can access files' && echo '' && claude --dangerously-skip-permissions"
    
    delay 2
    
    -- Show notification
    display notification "Check the Terminal window and try: /permissions" with title "Claude MCP Test"
end tell
EOF

echo ""
echo "INSTRUCTIONS FOR MANUAL VERIFICATION:"
echo "====================================="
echo "1. In the Terminal window that just opened, Claude should be running"
echo "2. Type: /permissions"
echo "3. Look for 'desktop-commander' in the list"
echo "4. If present, try: Read /tmp/test.txt"
echo "5. If it works without approval prompts, MCP is working!"
echo ""
echo "The issue appears to be that Claude Code needs you to:"
echo "- Either pre-approve desktop-commander via /permissions"
echo "- Or it may work automatically once you try to use it"
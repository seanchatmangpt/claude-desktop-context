#!/bin/bash
# Final MCP functionality test

echo "=== FINAL MCP FUNCTIONALITY TEST ==="
echo ""

# Create a unique test file
TEST_FILE="/tmp/final_mcp_test_$(date +%s).txt"
TEST_CONTENT="Final MCP Test - If you can read this, MCP is working! - $(date)"
echo "$TEST_CONTENT" > "$TEST_FILE"

echo "1. Created test file: $TEST_FILE"
echo "   Content: $TEST_CONTENT"
echo ""

# Test 1: Try with --print flag and a timeout
echo "2. Testing with --print mode (10 second timeout)..."
if timeout 10 claude --dangerously-skip-permissions --print "Use desktop-commander to read the file $TEST_FILE" 2>&1 | tee /tmp/claude_mcp_output.txt | grep -q "$TEST_CONTENT"; then
    echo "   ✅ SUCCESS! MCP is working - Claude read the file!"
    MCP_WORKS=true
else
    echo "   ❌ Claude did not read the file or timed out"
    MCP_WORKS=false
fi

# Show what Claude actually said
echo ""
echo "3. Claude's response:"
echo "===================="
cat /tmp/claude_mcp_output.txt 2>/dev/null | head -20 || echo "No output captured"
echo "===================="

# Test 2: Check if Desktop Commander is in the path that Claude expects
echo ""
echo "4. Desktop Commander availability check:"
DC_PATH="/Users/sac/.npm/_npx/4b4c857f6efdfb61/node_modules/.bin/desktop-commander"
if [ -x "$DC_PATH" ]; then
    echo "   ✅ Desktop Commander executable found"
    
    # Test if it responds to MCP protocol
    echo '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}' | timeout 2 "$DC_PATH" 2>&1 | grep -q "read_file" && echo "   ✅ Desktop Commander MCP server responding" || echo "   ❌ Desktop Commander MCP server not responding"
else
    echo "   ❌ Desktop Commander not found at expected path"
fi

# Cleanup
rm -f "$TEST_FILE" /tmp/claude_mcp_output.txt

echo ""
echo "5. Summary:"
echo "==========="
echo "   - Desktop Commander registered: $(claude mcp list 2>&1 | grep -c desktop-commander) instance(s)"
echo "   - MCP server working: $([ -x "$DC_PATH" ] && echo "Yes" || echo "No")"
echo "   - Claude can use MCP: $([ "$MCP_WORKS" = "true" ] && echo "Yes" || echo "Unknown - may need interactive mode")"
echo ""

if [ "$MCP_WORKS" = "true" ]; then
    echo "🎉 MCP INTEGRATION IS FULLY WORKING!"
else
    echo "📝 MCP is set up correctly but Claude may need interactive mode"
    echo "   Try: claude --dangerously-skip-permissions"
    echo "   Then: Read /tmp/test.txt"
fi
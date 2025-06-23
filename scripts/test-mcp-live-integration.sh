#!/bin/bash
# Live MCP Integration Test
# This test actually runs Claude and checks if it can use Desktop Commander

echo "=== LIVE MCP INTEGRATION TEST ==="
echo "Testing if Claude can actually use Desktop Commander through MCP"
echo ""

# Create a unique test file that Claude should be able to read
TEST_FILE="/tmp/mcp_test_$(date +%s).txt"
TEST_CONTENT="MCP Integration Test - Generated at $(date)"
echo "$TEST_CONTENT" > "$TEST_FILE"

echo "1. Created test file: $TEST_FILE"
echo "   Content: $TEST_CONTENT"
echo ""

# Create a Claude prompt that will test MCP functionality
PROMPT="Using the desktop-commander MCP server, please read the file at $TEST_FILE and tell me its contents. If you can't access the MCP server, just say 'MCP NOT WORKING'."

echo "2. Sending test prompt to Claude..."
echo "   Prompt: $PROMPT"
echo ""

# Run Claude with the test prompt
echo "3. Claude's response:"
echo "-------------------"

# Use a timeout to prevent hanging
timeout 30 claude --dangerously-skip-permissions "$PROMPT" 2>&1 | tee /tmp/mcp_test_output.txt

echo "-------------------"
echo ""

# Check if Claude successfully read the file
if grep -q "$TEST_CONTENT" /tmp/mcp_test_output.txt; then
    echo "✅ SUCCESS: Claude successfully read the file through MCP!"
    echo "   The MCP integration is working correctly."
    RESULT="SUCCESS"
elif grep -q "MCP NOT WORKING" /tmp/mcp_test_output.txt; then
    echo "❌ FAILURE: Claude explicitly said MCP is not working"
    RESULT="FAILURE"
elif grep -q "desktop-commander" /tmp/mcp_test_output.txt; then
    echo "⚠️  PARTIAL: Claude mentioned desktop-commander but couldn't read the file"
    RESULT="PARTIAL"
else
    echo "❓ UNKNOWN: Could not determine if MCP is working from the output"
    RESULT="UNKNOWN"
fi

# Cleanup
rm -f "$TEST_FILE" /tmp/mcp_test_output.txt

echo ""
echo "Test Result: $RESULT"
echo ""

# Additional diagnostics
echo "4. MCP Server Status:"
if claude mcp list 2>&1 | grep -q "desktop-commander"; then
    echo "   ✓ desktop-commander is registered with Claude"
else
    echo "   ✗ desktop-commander is NOT registered with Claude"
fi

echo ""
echo "5. Desktop Commander Accessibility:"
if [ -x "/Users/sac/.npm/_npx/4b4c857f6efdfb61/node_modules/.bin/desktop-commander" ]; then
    echo "   ✓ Desktop Commander binary is executable"
else
    echo "   ✗ Desktop Commander binary is NOT accessible"
fi
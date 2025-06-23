#!/bin/bash
# Simple test to check if Desktop Commander MCP is available in Claude

echo "=== CLAUDE MCP AVAILABILITY TEST ==="
echo ""

# First check if desktop-commander is registered
echo "1. Checking MCP registration..."
if claude mcp list 2>&1 | grep -q "desktop-commander"; then
    echo "   ✅ desktop-commander is registered"
else
    echo "   ❌ desktop-commander is NOT registered"
    echo "   Run: claude mcp add desktop-commander /Users/sac/.npm/_npx/4b4c857f6efdfb61/node_modules/.bin/desktop-commander"
    exit 1
fi

# Create a test prompt that asks Claude about available tools
PROMPT="/status"

echo ""
echo "2. Checking if Desktop Commander appears in Claude's available tools..."
echo "   Running: claude --dangerously-skip-permissions --print \"$PROMPT\""
echo ""

# Run Claude with the status command
OUTPUT=$(claude --dangerously-skip-permissions --print "$PROMPT" 2>&1)

echo "Claude's response:"
echo "================="
echo "$OUTPUT"
echo "================="
echo ""

# Check if Desktop Commander tools are mentioned
if echo "$OUTPUT" | grep -q -i "desktop.commander\|file system\|terminal\|process"; then
    echo "✅ Desktop Commander tools appear to be available!"
    TOOLS_AVAILABLE=true
else
    echo "⚠️  Desktop Commander tools not explicitly mentioned"
    TOOLS_AVAILABLE=false
fi

# Try a more direct test
echo ""
echo "3. Direct MCP functionality test..."
DIRECT_TEST="What MCP servers are available to you?"
echo "   Asking: $DIRECT_TEST"
echo ""

DIRECT_OUTPUT=$(claude --dangerously-skip-permissions --print "$DIRECT_TEST" 2>&1)
echo "$DIRECT_OUTPUT"
echo ""

# Final assessment
echo "========================================"
echo "ASSESSMENT:"
echo "========================================"

if [[ "$TOOLS_AVAILABLE" == "true" ]] || echo "$DIRECT_OUTPUT" | grep -q "desktop-commander"; then
    echo "✅ MCP INTEGRATION APPEARS TO BE WORKING"
    echo "   Desktop Commander should be accessible in Claude"
else
    echo "❓ UNCLEAR IF MCP IS WORKING"
    echo "   You may need to test interactively"
fi

echo ""
echo "To manually test, run:"
echo "  claude --dangerously-skip-permissions"
echo "Then try:"
echo "  'List files in /tmp'"
echo "  'Read /Users/sac/claude-desktop-context/manifest.yaml'"
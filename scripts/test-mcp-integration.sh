#!/bin/bash
# Test MCP Connection between Claude CLI and Desktop Commander

echo "Testing MCP Integration..."
echo "========================"

# Test 1: Check if Claude Desktop config exists
if [ -f "$HOME/.config/claude/claude_desktop_config.json" ]; then
    echo "✓ Claude Desktop config found"
    echo "  Config content:"
    cat "$HOME/.config/claude/claude_desktop_config.json" | sed 's/^/    /'
else
    echo "✗ Claude Desktop config missing at ~/.config/claude/claude_desktop_config.json"
fi

echo ""

# Test 2: Verify Desktop Commander is accessible
DC_PATH="/Users/sac/.npm/_npx/4b4c857f6efdfb61/node_modules/.bin/desktop-commander"
if [ -x "$DC_PATH" ]; then
    echo "✓ Desktop Commander found and executable"
    echo "  Path: $DC_PATH"
else
    echo "✗ Desktop Commander not found or not executable"
    echo "  Expected at: $DC_PATH"
fi

echo ""

# Test 3: Check if claude command exists
if command -v claude &> /dev/null; then
    echo "✓ Claude CLI is available"
else
    echo "✗ Claude CLI not found in PATH"
fi

echo ""
echo "To test the integration:"
echo "1. Run: claude --dangerously-skip-permissions"
echo "2. In Claude, try using Desktop Commander functions"
echo "3. They should work without manual approval prompts"
#!/bin/bash
# Test Claude's MCP connection to Desktop Commander

echo "Testing Claude's MCP connection to Desktop Commander..."
echo "======================================================="
echo ""

# Create a test prompt that should use Desktop Commander
PROMPT="Can you read the file at /Users/sac/mcp-test.txt and tell me what it says?"

# Run Claude with the prompt
echo "Sending test prompt to Claude..."
echo "Prompt: $PROMPT"
echo ""
echo "Claude's response:"
echo "-------------------"
claude --dangerously-skip-permissions "$PROMPT" 2>&1
#!/bin/bash
# Script to control iTerm2 and test Claude MCP integration

echo "=== AUTOMATED CLAUDE MCP TEST VIA ITERM2 ==="
echo "Controlling iTerm2 to test Desktop Commander integration..."
echo ""

# Create test file first
TEST_FILE="/tmp/mcp_interactive_test.txt"
TEST_CONTENT="MCP Test via iTerm automation - $(date)"
echo "$TEST_CONTENT" > "$TEST_FILE"

# AppleScript to control iTerm2
osascript <<EOF
tell application "iTerm2"
    -- Create new window
    create window with default profile
    
    tell current session of current window
        -- Start Claude
        write text "claude --dangerously-skip-permissions"
        delay 3
        
        -- Test 1: List files
        write text "Using desktop-commander, list the files in /tmp/"
        delay 5
        
        -- Test 2: Read specific file
        write text "Using desktop-commander, read the file $TEST_FILE"
        delay 5
        
        -- Test 3: Create a file
        write text "Using desktop-commander, create a file at /tmp/mcp_created.txt with content 'Created by Claude via MCP'"
        delay 5
        
        -- Test 4: Verify creation
        write text "Using desktop-commander, read /tmp/mcp_created.txt"
        delay 5
        
        -- Exit Claude
        write text "exit"
        delay 2
        
        -- Capture the session text
        set sessionText to text
        
        -- Write to file for analysis
        do shell script "echo " & quoted form of sessionText & " > /tmp/claude_mcp_session.txt"
    end tell
end tell
EOF

echo "Test session completed. Analyzing results..."
echo ""

# Wait for file to be written
sleep 2

# Analyze the session output
if [ -f /tmp/claude_mcp_session.txt ]; then
    echo "Session Output:"
    echo "=============="
    cat /tmp/claude_mcp_session.txt
    echo "=============="
    echo ""
    
    # Check for success indicators
    if grep -q "$TEST_CONTENT" /tmp/claude_mcp_session.txt; then
        echo "✅ SUCCESS: Claude read the test file content!"
        SUCCESS=true
    else
        echo "❌ FAILED: Claude did not read the test file"
        SUCCESS=false
    fi
    
    if [ -f /tmp/mcp_created.txt ]; then
        echo "✅ SUCCESS: Claude created the test file!"
        cat /tmp/mcp_created.txt
    else
        echo "❌ FAILED: Test file was not created"
    fi
else
    echo "❌ ERROR: Could not capture session output"
fi

# Cleanup
rm -f "$TEST_FILE" /tmp/mcp_created.txt /tmp/claude_mcp_session.txt

echo ""
echo "Test complete!"
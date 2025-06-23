#!/usr/bin/osascript

# Simple test to see what Claude outputs when asked about MCP

tell application "Terminal"
    activate
    
    # Start fresh
    do script ""
    delay 1
    
    # Run Claude with a simple MCP test
    do script "echo 'Testing MCP...' && claude --dangerously-skip-permissions --print 'Can you access desktop-commander MCP server? Just say YES if you can or NO if you cannot.'" in front window
    
    # Wait for response
    delay 10
    
    # Get the content of the terminal
    tell front window
        tell front tab
            set sessionContents to contents of selected tab
        end tell
    end tell
    
    # Try to capture using screenshot of terminal
    do script "screencapture -x /tmp/claude_terminal_test.png" in front window
    
    return "Check Terminal window for results"
end tell
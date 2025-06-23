#!/usr/bin/osascript

# AppleScript to test Claude MCP integration
# This will control Terminal app to run Claude and test Desktop Commander

on run
    tell application "Terminal"
        activate
        
        # Create a new window
        do script ""
        delay 1
        
        # Start Claude
        do script "claude --dangerously-skip-permissions" in front window
        delay 3
        
        # Send test commands
        do script "List files in /tmp using desktop-commander" in front window
        delay 3
        
        do script "Read /Users/sac/claude-desktop-context/manifest.yaml using desktop-commander" in front window
        delay 3
        
        do script "Create a file at /tmp/applescript_mcp_test.txt with content 'MCP test via AppleScript'" in front window
        delay 3
        
        # Check if file was created
        do script "exit" in front window
        delay 1
        
        # Now check if the file exists
        do script "ls -la /tmp/applescript_mcp_test.txt" in front window
        delay 2
        
        # Get the window content
        set windowContent to contents of front window
        
        # Save to file for analysis
        do shell script "echo " & quoted form of windowContent & " > /tmp/claude_mcp_test_result.txt"
    end tell
    
    # Check if test file was created
    try
        do shell script "cat /tmp/applescript_mcp_test.txt"
        display notification "MCP Integration Working!" with title "Success"
        return "SUCCESS: File was created by Claude via MCP"
    on error
        display notification "MCP Integration Failed" with title "Failed"
        return "FAILED: File was not created"
    end try
end run
#!/usr/bin/osascript

# Test Claude MCP using actual keystrokes instead of script commands

on run
    -- Create test file first
    do shell script "echo 'MCP Keystroke Test - ' & date > /tmp/mcp_keystroke_test.txt"
    
    tell application "Terminal"
        activate
        
        -- Create new window
        do script ""
        delay 1
        
        -- Start Claude using keystrokes
        tell application "System Events"
            keystroke "claude --dangerously-skip-permissions"
            keystroke return
            delay 5 -- Wait for Claude to start
            
            -- Type the test command
            keystroke "Read the file /tmp/mcp_keystroke_test.txt using desktop-commander"
            keystroke return
            delay 5 -- Wait for response
            
            -- Take a screenshot to capture result
            do shell script "screencapture -x /tmp/claude_mcp_test_screenshot.png"
            
            -- Try another test - create a file
            keystroke "Create a file at /tmp/mcp_created_via_keystrokes.txt with content 'Success! MCP is working!'"
            keystroke return
            delay 5
            
            -- Exit Claude
            keystroke "exit"
            keystroke return
        end tell
    end tell
    
    -- Check if the file was created
    delay 2
    try
        set fileContent to do shell script "cat /tmp/mcp_created_via_keystrokes.txt"
        display notification "MCP is working! File created: " & fileContent with title "✅ Success"
        return "SUCCESS: " & fileContent
    on error
        -- Check screenshot
        display notification "Check /tmp/claude_mcp_test_screenshot.png for results" with title "Test Complete"
        return "File not created - check screenshot at /tmp/claude_mcp_test_screenshot.png"
    end try
end run
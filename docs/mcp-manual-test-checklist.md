# Quick MCP Integration Test Checklist

Copy and paste these commands one by one in Claude CLI to verify MCP works:

## 1. Start Claude
```bash
claude --dangerously-skip-permissions
```

## 2. Test File Operations
```
List all files in /tmp

Read the file /Users/sac/claude-desktop-context/manifest.yaml

Create a file at /tmp/mcp_test.txt with content "MCP is working!"

Read the file /tmp/mcp_test.txt to verify it was created
```

## 3. Test Command Execution
```
Run the command 'echo "Hello from MCP"'

Show me the current date and time using the date command

List running processes that contain 'claude'
```

## 4. Test CDCS Integration
```
Read the first 50 lines of /Users/sac/claude-desktop-context/memory/sessions/active/chunk_001.md

Search for files containing "MCP" in /Users/sac/claude-desktop-context/
```

## Expected Results if MCP Works:
- ✅ No approval prompts
- ✅ Direct file access
- ✅ Command execution results
- ✅ File creation success

## If MCP is NOT Working:
- ❌ "I don't have access to..." messages
- ❌ Approval prompts for each operation
- ❌ No actual file/command results

Save this checklist and run through it to verify your MCP setup!
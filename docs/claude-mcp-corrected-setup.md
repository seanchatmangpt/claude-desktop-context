# Claude CLI + DesktopCommanderMCP Integration

## Corrected Setup for Your Environment

### Configuration Files Created:
1. **Claude Desktop Config**: `~/.config/claude/claude_desktop_config.json`
   - This is where Claude CLI looks for MCP server configurations
   - Desktop Commander path is hardcoded to your npx installation

2. **Alternative Config**: `~/.config/claude-code/config.json`
   - Backup location if Claude CLI uses a different config path

### Your Commands:
- **Claude CLI**: `claude --dangerously-skip-permissions`
- **Desktop Commander**: `/Users/sac/.npm/_npx/4b4c857f6efdfb61/node_modules/.bin/desktop-commander`

### How Desktop Commander MCP Works:
- Desktop Commander runs in MCP mode by default (no special arguments needed)
- It provides a stdio-based server that Claude can connect to
- The connection is automatic when both are configured

### To Use:
```bash
# Simply run Claude - it will auto-connect to Desktop Commander
claude --dangerously-skip-permissions

# Desktop Commander will be started automatically by Claude when needed
```

### Testing the Connection:
Once in Claude CLI, you should be able to use Desktop Commander functions like:
- Reading/writing files
- Executing commands
- Searching code
- All without manual approval prompts

### Troubleshooting:
If the connection doesn't work:
1. Check if Desktop Commander is accessible: 
   `/Users/sac/.npm/_npx/4b4c857f6efdfb61/node_modules/.bin/desktop-commander`
2. Verify config exists: 
   `cat ~/.config/claude/claude_desktop_config.json`
3. Try running Desktop Commander directly to see if it starts

### Based on:
https://github.com/wonderwhy-er/DesktopCommanderMCP
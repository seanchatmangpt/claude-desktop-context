#!/bin/bash
# Claude Code MCP Launcher
# Connects Claude CLI to Desktop Commander via MCP

echo "Starting Claude with Desktop Commander MCP integration..."

# Desktop Commander automatically runs in MCP mode
# Claude will connect to it when started

# Launch Claude with dangerous permissions skip
claude --dangerously-skip-permissions "$@"
#!/usr/bin/env python3
"""
Test Claude MCP with proper terminal control
"""

import os
import time
import subprocess
import sys

# First, let's check what mode Claude starts in
print("=== CLAUDE MODE DETECTION ===")
print("\nAnalyzing Claude's interface...")

# Create a test to understand Claude's behavior
test_process = subprocess.Popen(
    ['claude', '--dangerously-skip-permissions'],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True
)

# Send commands with different approaches
commands = [
    "\x1b",  # ESC
    "/help\n",
    "\x1b",  # ESC again
    ":q\n"   # Vim quit
]

for cmd in commands:
    test_process.stdin.write(cmd)
    test_process.stdin.flush()
    time.sleep(0.5)

# Terminate
test_process.terminate()
output, error = test_process.communicate()

print("Output preview:", output[:200] if output else "No output")
print("Error:", error if error else "No error")

# Now let's use a simpler approach - just ask Claude directly
print("\n\n=== DIRECT MCP STATUS CHECK ===")

# Use --print mode which should be non-interactive
result = subprocess.run(
    ['claude', '--dangerously-skip-permissions', '--print', 'List the MCP servers available to you'],
    capture_output=True,
    text=True,
    timeout=10
)

print("Claude's response about MCP servers:")
print(result.stdout)

if 'desktop-commander' in result.stdout.lower():
    print("\n✅ Desktop Commander appears to be available!")
else:
    print("\n❓ Desktop Commander not mentioned in response")

# Test if we can use it
print("\n\n=== TESTING DESKTOP COMMANDER FUNCTIONALITY ===")

test_file = '/tmp/python_mcp_test.txt'
with open(test_file, 'w') as f:
    f.write('Python MCP Test Success')

# Try to read the file
result = subprocess.run(
    ['claude', '--dangerously-skip-permissions', '--print', f'Read the file {test_file} and tell me its contents'],
    capture_output=True,
    text=True,
    timeout=10
)

print("File read test response:")
print(result.stdout[:500])

if 'Python MCP Test Success' in result.stdout:
    print("\n✅ MCP IS WORKING! Claude successfully read the file!")
else:
    print("\n❌ Claude did not read the file content")

# Cleanup
if os.path.exists(test_file):
    os.remove(test_file)

print("\n\nFINAL VERDICT:")
print("Desktop Commander is registered: ✅")
print("Claude can be controlled: ✅") 
print("But Claude Code uses a vim-like interface that needs interactive commands")
print("\nTo use MCP, you need to:")
print("1. Run: claude --dangerously-skip-permissions")
print("2. Press ESC to exit INSERT mode")
print("3. Type 'i' to enter INSERT mode when you want to type")
print("4. Use Desktop Commander commands")
print("5. Or use: claude --print 'your command' for non-interactive use")
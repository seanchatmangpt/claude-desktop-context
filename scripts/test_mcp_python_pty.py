#!/usr/bin/env python3
"""
Test Claude MCP using Python's pty module for proper terminal emulation
"""

import os
import pty
import select
import subprocess
import sys
import time
import termios
import tty

def test_claude_mcp():
    print("=== CLAUDE MCP PTY TEST ===\n")
    
    # Create test file
    test_file = "/tmp/mcp_python_pty_test.txt"
    test_content = f"MCP Python PTY Test - {time.ctime()}"
    with open(test_file, 'w') as f:
        f.write(test_content)
    
    print(f"Created test file: {test_file}")
    print(f"Content: {test_content}\n")
    
    # Start Claude in a pseudo-terminal
    print("Starting Claude in PTY...")
    master, slave = pty.openpty()
    
    process = subprocess.Popen(
        ['claude', '--dangerously-skip-permissions'],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        preexec_fn=os.setsid
    )
    
    os.close(slave)
    
    # Make it non-blocking
    import fcntl
    flags = fcntl.fcntl(master, fcntl.F_GETFL)
    fcntl.fcntl(master, fcntl.F_SETFL, flags | os.O_NONBLOCK)
    
    output_buffer = ""
    success = False
    
    def read_output(timeout=5):
        nonlocal output_buffer
        end_time = time.time() + timeout
        while time.time() < end_time:
            ready, _, _ = select.select([master], [], [], 0.1)
            if ready:
                try:
                    data = os.read(master, 1024).decode('utf-8', errors='ignore')
                    output_buffer += data
                    print(data, end='', flush=True)
                except OSError:
                    break
            if ">" in output_buffer or "Claude" in output_buffer:
                break
        return output_buffer
    
    # Wait for Claude to start
    print("Waiting for Claude to initialize...")
    read_output(5)
    
    # Send test command
    print("\n\nSending test command...")
    test_command = f"Read the file {test_file}\\n"
    os.write(master, test_command.encode())
    
    # Read response
    print("Waiting for response...")
    response = read_output(5)
    
    if test_content in response:
        print(f"\n✅ SUCCESS! Claude read the file content!")
        success = True
    else:
        print(f"\n❌ Claude did not read the file content")
    
    # Try file creation
    print("\nTesting file creation...")
    create_command = "Create a file at /tmp/mcp_python_created.txt with content 'Python PTY success'\\n"
    os.write(master, create_command.encode())
    
    read_output(5)
    
    # Exit Claude
    os.write(master, b"exit\\n")
    time.sleep(1)
    
    # Cleanup
    os.close(master)
    process.terminate()
    
    # Check if file was created
    if os.path.exists("/tmp/mcp_python_created.txt"):
        with open("/tmp/mcp_python_created.txt", 'r') as f:
            content = f.read()
        print(f"\n✅ File creation successful! Content: {content}")
        os.remove("/tmp/mcp_python_created.txt")
    else:
        print("\n❌ File was not created")
    
    # Cleanup test file
    if os.path.exists(test_file):
        os.remove(test_file)
    
    return success

if __name__ == "__main__":
    try:
        success = test_claude_mcp()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)
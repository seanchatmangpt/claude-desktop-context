#!/usr/bin/env python3
"""
Interactive MCP Integration Test
Uses pexpect to control Claude CLI and verify Desktop Commander works
"""

import subprocess
import time
import sys
import os

try:
    import pexpect
except ImportError:
    print("Installing pexpect...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pexpect"])
    import pexpect

def test_mcp_integration():
    """Test if Claude can actually use Desktop Commander via MCP"""
    
    print("=== INTERACTIVE CLAUDE MCP INTEGRATION TEST ===")
    print("Testing Desktop Commander MCP connection...\n")
    
    # Create test file
    test_file = f"/tmp/mcp_test_{int(time.time())}.txt"
    test_content = f"MCP Integration Test - {time.ctime()}"
    with open(test_file, 'w') as f:
        f.write(test_content)
    print(f"1. Created test file: {test_file}")
    print(f"   Content: {test_content}\n")
    
    try:
        # Start Claude CLI
        print("2. Starting Claude CLI...")
        child = pexpect.spawn('claude --dangerously-skip-permissions', timeout=30)
        child.logfile_read = sys.stdout.buffer  # Show output in real-time
        
        # Wait for Claude to be ready
        time.sleep(2)
        
        # Test 1: List files
        print("\n3. Testing file listing...")
        child.sendline("List the files in /tmp/ using desktop-commander")
        child.expect([pexpect.TIMEOUT, pexpect.EOF], timeout=10)
        
        # Test 2: Read specific file
        print(f"\n4. Testing file reading...")
        child.sendline(f"Read the file {test_file} using desktop-commander")
        
        # Look for our test content in response
        index = child.expect([test_content, "MCP NOT WORKING", pexpect.TIMEOUT], timeout=10)
        
        if index == 0:
            print(f"\n✅ SUCCESS: Claude successfully read the file!")
            print("   MCP integration is working correctly!")
            success = True
        elif index == 1:
            print("\n❌ FAILURE: Claude says MCP is not working")
            success = False
        else:
            print("\n⚠️  TIMEOUT: No clear response from Claude")
            success = False
            
        # Test 3: Create a file
        print("\n5. Testing file creation...")
        created_file = "/tmp/mcp_created_test.txt"
        child.sendline(f"Create a file at {created_file} with content 'MCP Write Test Success' using desktop-commander")
        time.sleep(5)
        
        # Exit Claude
        child.sendline("exit")
        child.expect([pexpect.EOF, pexpect.TIMEOUT], timeout=5)
        child.close()
        
        # Check if file was created
        if os.path.exists(created_file):
            with open(created_file, 'r') as f:
                content = f.read()
            print(f"\n✅ File creation successful!")
            print(f"   Content: {content}")
            os.remove(created_file)
        else:
            print("\n❌ File was not created")
            
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        success = False
    finally:
        # Cleanup
        if os.path.exists(test_file):
            os.remove(test_file)
    
    # Summary
    print("\n" + "="*50)
    print("TEST SUMMARY:")
    print("="*50)
    
    # Check MCP registration
    try:
        result = subprocess.run(['claude', 'mcp', 'list'], 
                              capture_output=True, text=True)
        if 'desktop-commander' in result.stdout:
            print("✅ Desktop Commander is registered with Claude")
        else:
            print("❌ Desktop Commander is NOT registered")
    except:
        print("❌ Could not check MCP registration")
    
    if success:
        print("\n🎉 MCP INTEGRATION IS WORKING!")
    else:
        print("\n❌ MCP INTEGRATION TEST FAILED")
        print("\nTroubleshooting:")
        print("1. Make sure Desktop Commander is installed")
        print("2. Try: claude mcp list")
        print("3. If not listed, run: claude mcp add desktop-commander /path/to/desktop-commander")

if __name__ == "__main__":
    test_mcp_integration()
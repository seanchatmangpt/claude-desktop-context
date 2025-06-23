#!/bin/bash
# Basic CDCS functionality test

echo "=== CDCS BASIC FUNCTIONALITY TEST ==="
echo ""

# Test 1: Check if CDCS directory structure exists
echo "1. Checking CDCS directory structure..."
CDCS_DIR="/Users/sac/claude-desktop-context"
REQUIRED_DIRS="memory patterns agents emergent-capabilities evolution hooks"

for dir in $REQUIRED_DIRS; do
    if [ -d "$CDCS_DIR/$dir" ]; then
        echo "   ✅ $dir/"
    else
        echo "   ❌ $dir/ (missing)"
    fi
done

# Test 2: Check manifest
echo ""
echo "2. Checking manifest.yaml..."
if [ -f "$CDCS_DIR/manifest.yaml" ]; then
    VERSION=$(grep "^version:" "$CDCS_DIR/manifest.yaml" | cut -d'"' -f2)
    echo "   ✅ Found version: $VERSION"
else
    echo "   ❌ manifest.yaml not found"
fi

# Test 3: Test file operations
echo ""
echo "3. Testing file operations..."
TEST_FILE="$CDCS_DIR/test_output.txt"
echo "Test content $(date)" > "$TEST_FILE"
if [ -f "$TEST_FILE" ]; then
    echo "   ✅ Write test successful"
    rm "$TEST_FILE"
else
    echo "   ❌ Write test failed"
fi

# Test 4: Check memory system
echo ""
echo "4. Checking memory system..."
MEMORY_DIR="$CDCS_DIR/memory/sessions"
if [ -d "$MEMORY_DIR" ]; then
    SESSION_COUNT=$(find "$MEMORY_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "   ✅ Memory system ready ($SESSION_COUNT sessions found)"
else
    echo "   ❌ Memory system not initialized"
fi

echo ""
echo "=== TEST COMPLETE ==="

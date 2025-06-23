#!/bin/bash
# CDCS Tree Command - Styled perspective generator
# Usage: /tree [depth] [focus-area]

DEPTH=${1:-3}
FOCUS=${2:-""}
BASE_DIR="/Users/sac/claude-desktop-context"

echo "🌳 CDCS Tree Perspective"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$FOCUS" ]; then
    echo "📍 Focus Area: $FOCUS"
    tree -L $DEPTH -I '__pycache__|*.pyc|.venv|node_modules|.git' --prune "$BASE_DIR/$FOCUS" 2>/dev/null || echo "❌ Focus area not found"
else
    echo "🔍 Overview (depth: $DEPTH)"
    tree -L $DEPTH -I '__pycache__|*.pyc|.venv|node_modules|.git' --prune "$BASE_DIR"
fi

echo ""
echo "📊 Quick Stats:"
find "$BASE_DIR" -type d | wc -l | sed 's/^/   📁 Directories: /'
find "$BASE_DIR" -type f | wc -l | sed 's/^/   📄 Files: /'

echo ""
echo "🎯 Key Areas:"
ls -la "$BASE_DIR" | grep "^d" | awk '{print "   •", $9}' | grep -v "\.$"

echo ""
echo "💡 Usage: /tree [depth] [focus-area]"
echo "   Examples: /tree 2, /tree 4 memory, /tree 3 spr_kernels"

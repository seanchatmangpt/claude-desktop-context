#!/bin/bash
# Quick test script to verify CDCS tree commands are working

echo "🧪 Testing CDCS Tree Commands"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test if commands directory is in PATH
if [[ ":$PATH:" == *":/Users/sac/claude-desktop-context/commands:"* ]]; then
    echo "✅ CDCS commands directory is in PATH"
else
    echo "❌ CDCS commands directory not found in PATH"
    echo "PATH: $PATH"
fi

# Test command files exist and are executable
echo ""
echo "📁 Checking command files:"

commands=("semantic_tree.sh" "src_tree.sh" "nuxt_tree.sh")
for cmd in "${commands[@]}"; do
    if [ -x "/Users/sac/claude-desktop-context/commands/$cmd" ]; then
        echo "✅ $cmd is executable"
    else
        echo "❌ $cmd not found or not executable"
    fi
done

# Test aliases are loaded
echo ""
echo "🔗 Testing aliases:"

test_aliases=("tree" "src-tree" "nuxt-comp" "cd-chat" "dev-chat")
for alias_name in "${test_aliases[@]}"; do
    if alias "$alias_name" >/dev/null 2>&1; then
        echo "✅ $alias_name alias loaded"
    else
        echo "❌ $alias_name alias not found"
    fi
done

echo ""
echo "💡 To reload shell configuration: source ~/.zshrc"
echo "🚀 To test: try 'tree2' or 'nuxt-comp' commands"

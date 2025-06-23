# CDCS Semantic Tree Aliases
# Add to your ~/.bashrc or ~/.zshrc

# Main semantic tree command
alias tree="/Users/sac/claude-desktop-context/commands/semantic_tree.sh"

# Quick tree variants
alias tree-spr="/Users/sac/claude-desktop-context/commands/semantic_tree.sh spr"
alias tree-memory="/Users/sac/claude-desktop-context/commands/semantic_tree.sh memory"
alias tree-active="/Users/sac/claude-desktop-context/commands/semantic_tree.sh active"
alias tree-patterns="/Users/sac/claude-desktop-context/commands/semantic_tree.sh patterns"

# Tree with different depths
alias tree2="/Users/sac/claude-desktop-context/commands/semantic_tree.sh overview 2"
alias tree4="/Users/sac/claude-desktop-context/commands/semantic_tree.sh overview 4"
alias tree6="/Users/sac/claude-desktop-context/commands/semantic_tree.sh overview 6"

# Legacy tree with styling
alias tree-legacy="/Users/sac/claude-desktop-context/commands/tree_command.sh"

echo "✓ CDCS Semantic Tree aliases loaded"
echo "💡 Usage: tree, tree-spr, tree-memory, tree-active, tree-patterns"
echo "🌳 Depths: tree2, tree4, tree6"

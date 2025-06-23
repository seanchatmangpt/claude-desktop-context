# 🌳 CDCS Semantic Tree Command System

## Quick Setup
```bash
# Load aliases (add to ~/.bashrc or ~/.zshrc)
source /Users/sac/claude-desktop-context/commands/tree_aliases.sh

# Or use directly
/Users/sac/claude-desktop-context/commands/semantic_tree.sh [focus] [depth]
```

## Command Modes

### `/tree` - System Overview
```bash
tree                    # Overview depth 3
tree overview 4         # Overview depth 4  
tree2                   # Quick depth 2
tree4                   # Quick depth 4
```

### `/tree spr` - SPR Kernels & Patterns
```bash
tree spr                # SPR kernels structure
tree-spr                # Quick alias
```
**Shows**: SPR files, pattern connections, efficiency metrics

### `/tree memory` - Memory Architecture  
```bash
tree memory             # Memory system
tree memory 4           # Deeper memory view
tree-memory             # Quick alias
```
**Shows**: Sessions, chunks, archives, current context

### `/tree active` - Current Working Context
```bash
tree active             # Active session
tree-active             # Quick alias
```
**Shows**: Current session files, working context, session links

### `/tree patterns` - Conceptual Architecture
```bash
tree patterns           # Pattern graph visualization
tree-patterns           # Quick alias  
```
**Shows**: CDCS v3.0 conceptual structure, SPR→file relationships

## SPR-Enhanced Features

✓ **Latent Priming**: Activates relevant knowledge before tree generation
✓ **Pattern Connections**: Shows semantic relationships as tree branches  
✓ **Efficiency Metrics**: Displays SPR vs file token usage
✓ **Context Awareness**: Highlights current session and active patterns
✓ **Smart Navigation**: Suggests next exploration based on context

## Output Format
```
🌳 CDCS Tree Perspective: [focus]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Activating SPR anchors for: [focus]
  → [relevant-patterns-activated]

[tree-structure-with-context]

📊 System Stats:
  📁 Directories: X
  📄 Files: Y  
  🧠 SPR Kernels: Z (enabling 80% token reduction)

💡 Navigation Suggestions:
  → Try: [contextual-suggestions]
```

## Integration with CDCS v3.0

This tree command follows the CDCS v3.0 philosophy:
- **SPR-first**: Activates conceptual anchors before file operations
- **Hybrid efficiency**: 80% fewer tokens through smart priming
- **Pattern-aware**: Shows semantic relationships, not just file structure
- **Context-sensitive**: Adapts output based on current session state

## Examples

**Quick system overview**:
```bash
tree2                   # Fast 2-level overview
```

**Deep SPR analysis**:
```bash
tree spr 4              # Detailed SPR structure
```

**Current work context**:
```bash
tree active             # See what you're working on
```

**Understand the architecture**:
```bash
tree patterns           # Conceptual view of CDCS v3.0
```

The tree command gives you perspective on your 18K+ directories and 100K+ files through SPR-enhanced navigation that activates the right knowledge context before showing you the structure.

# CDCS Semantic Tree Command Integration
# Part of CDCS v3.0 with SPR-enhanced perspective

## /tree Command Definition

**Purpose**: Generate contextual perspective of CDCS structure using SPR-enhanced navigation

**Syntax**: `/tree [focus] [depth] [mode]`

**Modes**:
- `overview` - High-level system perspective (default)
- `spr` - SPR kernels and pattern connections
- `memory` - Session and memory architecture
- `active` - Current working context
- `patterns` - Pattern recognition tree
- `full` - Complete structure with stats

**Examples**:
```
/tree                    → Overview with depth 3
/tree spr                → SPR kernels structure  
/tree memory 4           → Memory system depth 4
/tree patterns overview  → Pattern connections
/tree active full        → Complete active context
```

**Integration Points**:
- Activates relevant SPR kernels before tree generation
- Shows pattern connections as tree branches
- Highlights active session context
- Displays file→SPR mapping efficiency
- Provides token usage perspectives

**SPR Enhancement**: 
Before generating tree, activate conceptual anchors:
- System architecture patterns
- File organization principles  
- Memory hierarchy structure
- Active session context

**Output Format**:
```
🌳 CDCS Tree: [focus-area]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ SPR Anchors: [relevant-patterns]
📍 Context: [current-session]

[tree-structure]

💡 Insights: [pattern-connections]
📊 Efficiency: [spr-vs-file-stats]
```

**Behavioral Notes**:
- Always SPR-prime before tree generation
- Show conceptual connections as tree branches
- Highlight efficiency gains from SPR usage
- Provide actionable navigation suggestions

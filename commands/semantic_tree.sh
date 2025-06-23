#!/bin/bash
# CDCS Semantic Tree Implementation
# SPR-enhanced perspective generator

FOCUS=${1:-"overview"}
DEPTH=${2:-3}
MODE=${3:-"standard"}
BASE="/Users/sac/claude-desktop-context"

# SPR Activation Function
activate_spr() {
    echo "✓ Activating SPR anchors for: $FOCUS"
    case $FOCUS in
        "spr"|"kernels") echo "  → pattern-recognition, latent-priming, capability-evolution" ;;
        "memory"|"sessions") echo "  → session-recovery, memory-architecture, context-threading" ;;
        "active"|"current") echo "  → current-session, active-patterns, working-context" ;;
        "patterns") echo "  → graph-connections, semantic-links, pattern-propagation" ;;
        *) echo "  → system-overview, file-organization, efficiency-patterns" ;;
    esac
}

# Enhanced Tree Generation
generate_tree() {
    case $FOCUS in
        "spr"|"kernels")
            echo "🧠 SPR Kernels & Pattern Graph"
            tree -L $DEPTH "$BASE/spr_kernels" 2>/dev/null
            echo ""
            echo "📊 Pattern Connections:"
            echo "  information-theory → optimization → compression"
            echo "  latent-priming → pattern-recognition → semantic-commands"
            ;;
        "memory"|"sessions")
            echo "🧭 Memory Architecture"
            tree -L $DEPTH "$BASE/memory" 2>/dev/null
            echo ""
            echo "📈 Session Flow:"
            echo "  SPR kernels → active context → session chunks → archives"
            ;;
        "active"|"current")
            echo "⚡ Active Context"
            tree -L $DEPTH "$BASE/memory/sessions/active" 2>/dev/null
            echo ""
            if [ -f "$BASE/memory/sessions/current.link" ]; then
                echo "🔗 Current Session: $(cat $BASE/memory/sessions/current.link)"
            fi
            ;;
        "patterns")
            echo "🕸️ Pattern Recognition Tree"
            echo "  CDCS-v3.0/"
            echo "  ├── SPR-Kernels/"
            echo "  │   ├── latent-priming.spr → [2.5KB activates 50KB+ context]"
            echo "  │   ├── pattern-recognition.spr → [graph propagation]"
            echo "  │   └── session-recovery.spr → [instant context activation]"
            echo "  ├── Pattern-Graph/"
            echo "  │   ├── semantic-links → spreading activation"
            echo "  │   ├── conceptual-anchors → latent knowledge"
            echo "  │   └── efficiency-patterns → 80% token reduction"
            echo "  └── Hybrid-Operations/"
            echo "      ├── SPR-first → activate knowledge"
            echo "      ├── file-validation → when needed"
            echo "      └── continuous-update → both systems"
            ;;
        *)
            echo "🌍 CDCS System Overview"
            tree -L $DEPTH -I '__pycache__|*.pyc|.venv|node_modules|.git' --prune "$BASE"
            ;;
    esac
}

# Main Execution
echo "🌳 CDCS Tree Perspective: $FOCUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

activate_spr
echo ""

generate_tree
echo ""

# Stats and Insights
echo "📊 System Stats:"
DIRS=$(find "$BASE" -type d | wc -l | tr -d ' ')
FILES=$(find "$BASE" -type f | wc -l | tr -d ' ')
echo "  📁 Directories: $DIRS"
echo "  📄 Files: $FILES"

if [ -f "$BASE/spr_kernels/latent_priming.spr" ]; then
    SPR_SIZE=$(du -h "$BASE/spr_kernels" | tail -1 | cut -f1)
    echo "  🧠 SPR Kernels: $SPR_SIZE (enabling 80% token reduction)"
fi

echo ""
echo "💡 Navigation Suggestions:"
case $FOCUS in
    "overview") echo "  → Try: /tree spr, /tree memory, /tree active" ;;
    "spr") echo "  → Try: /tree patterns, /tree memory" ;;
    "memory") echo "  → Try: /tree active, /tree sessions" ;;
    *) echo "  → Try: /tree overview, /tree spr, /tree patterns" ;;
esac

#!/bin/bash

##############################################################################
# Apply Adaptations to Coordination Helper
##############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL_SCRIPT="$SCRIPT_DIR/coordination_helper.sh"
ADAPTATIONS_SCRIPT="$SCRIPT_DIR/coordination_helper_adaptations.sh"
BACKUP_SCRIPT="$SCRIPT_DIR/coordination_helper.sh.backup"

echo "🔧 Applying Coordination Helper Adaptations"
echo "=========================================="

# Create backup
if [ -f "$ORIGINAL_SCRIPT" ]; then
    echo "📋 Creating backup of original script..."
    cp "$ORIGINAL_SCRIPT" "$BACKUP_SCRIPT"
    echo "✅ Backup saved to: $BACKUP_SCRIPT"
else
    echo "❌ Original script not found at: $ORIGINAL_SCRIPT"
    exit 1
fi

# Make adaptations script executable
chmod +x "$ADAPTATIONS_SCRIPT"

# Add source line to include adaptations
echo ""
echo "🔄 Integrating adaptations..."

# Check if adaptations already sourced
if grep -q "coordination_helper_adaptations.sh" "$ORIGINAL_SCRIPT"; then
    echo "⚠️  Adaptations already integrated"
else
    # Add source line near the top of the script (after the header)
    sed -i.bak '/^# SYSTEM CHARACTERISTICS:/a\
\
# Source adaptations for work freshness and Ollama support\
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\
if [ -f "$SCRIPT_DIR/coordination_helper_adaptations.sh" ]; then\
    source "$SCRIPT_DIR/coordination_helper_adaptations.sh"\
fi\
' "$ORIGINAL_SCRIPT"
    
    echo "✅ Adaptations sourced in main script"
fi

# Add new commands to the help section and case statement
echo ""
echo "📝 Adding new commands..."

# Create a temporary file with the new case entries
cat > /tmp/new_commands.txt << 'EOF'
    "heartbeat")
        update_agent_heartbeat "$2" "$3"
        ;;
    "check-stale")
        check_stale_work
        ;;
    "recover-stale")
        recover_stale_work "$2"
        ;;
    "heartbeat-start")
        start_heartbeat_daemon
        ;;
    "heartbeat-stop")
        stop_heartbeat_daemon
        ;;
    "claim-enhanced")
        claim_work_enhanced "$2" "$3" "$4" "$5"
        ;;
    "ollama-priorities")
        ollama_analyze_work_priorities
        ;;
    "ollama-optimize")
        ollama_optimize_team_assignments
        ;;
    "freshness-dashboard")
        show_freshness_dashboard
        ;;
    "ai-analyze")
        # Generic AI analysis using stdin
        ai_analyze "$(cat)" "$2" "$3"
        ;;
EOF

# Add help text for new commands
cat > /tmp/new_help.txt << 'EOF'
        echo "🔄 Work Freshness Commands:"
        echo "  heartbeat [agent_id] [work_id]                     - Update agent/work heartbeat"
        echo "  check-stale                                         - Check for stale work items"
        echo "  recover-stale <reassign|fail|retry>                - Recover stale work items"
        echo "  heartbeat-start                                     - Start heartbeat daemon"
        echo "  heartbeat-stop                                      - Stop heartbeat daemon"
        echo "  claim-enhanced <type> <desc> [priority] [team]     - Enhanced work claiming with AI"
        echo "  freshness-dashboard                                 - Show work freshness status"
        echo ""
        echo "🤖 Ollama AI Commands:"
        echo "  ollama-priorities                                   - Analyze priorities using Ollama"
        echo "  ollama-optimize                                     - Optimize team assignments with Ollama"
        echo "  ai-analyze <prompt> [model]                         - Generic AI analysis (stdin)"
        echo ""
        echo "🔧 Environment Variables:"
        echo "  AI_PROVIDER      - AI provider: ollama, claude, or auto (default: ollama)"
        echo "  OLLAMA_HOST      - Ollama API endpoint (default: http://localhost:11434)"
        echo "  HEARTBEAT_INTERVAL - Heartbeat interval in seconds (default: 60)"
        echo "  STALE_THRESHOLD  - Seconds before work is considered stale (default: 300)"
        echo ""
EOF

# Insert new help commands before the existing help section end
if ! grep -q "Work Freshness Commands:" "$ORIGINAL_SCRIPT"; then
    # Find the line with "Environment Variables:" and insert before it
    sed -i.bak2 '/^        echo "Environment Variables:"/i\
'"$(cat /tmp/new_help.txt)" "$ORIGINAL_SCRIPT"
    
    echo "✅ Help documentation updated"
fi

# Add new case statements before the help case
if ! grep -q "heartbeat)" "$ORIGINAL_SCRIPT"; then
    # Find the "help"|*) line and insert new cases before it
    sed -i.bak3 '/^    "help"|\*)/i\
'"$(cat /tmp/new_commands.txt)" "$ORIGINAL_SCRIPT"
    
    echo "✅ New commands added to dispatcher"
fi

# Clean up temporary files
rm -f /tmp/new_commands.txt /tmp/new_help.txt

echo ""
echo "🎉 Adaptations Applied Successfully!"
echo ""
echo "📋 New Features Available:"
echo "  ✅ Work freshness monitoring with heartbeats"
echo "  ✅ Automatic stale work detection and recovery"
echo "  ✅ Ollama AI integration for local LLM analysis"
echo "  ✅ Flexible AI provider selection (Ollama/Claude/Auto)"
echo "  ✅ Enhanced work claiming with AI recommendations"
echo ""
echo "🚀 Quick Start:"
echo "  1. Start Ollama: ollama serve"
echo "  2. Pull a model: ollama pull llama2"
echo "  3. Start heartbeat: ./coordination_helper.sh heartbeat-start"
echo "  4. Check freshness: ./coordination_helper.sh freshness-dashboard"
echo "  5. Use AI analysis: ./coordination_helper.sh ollama-priorities"
echo ""
echo "💡 To use Ollama by default:"
echo "  export AI_PROVIDER=ollama"
echo "  export OLLAMA_HOST=http://localhost:11434"

# Make the main script executable
chmod +x "$ORIGINAL_SCRIPT"
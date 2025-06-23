#!/bin/bash

echo "🤖 CDCS Autonomous System Setup"
echo "==============================="
echo ""
echo "This will set up a fully autonomous system that:"
echo "• Monitors telemetry data continuously"
echo "• Analyzes patterns with AI (Ollama)"
echo "• Creates optimization tasks automatically"
echo "• Self-heals when errors occur"
echo "• Maintains system health"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# 1. Check Ollama
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    MODEL=$(curl -s http://localhost:11434/api/tags | jq -r '.models[0].name')
    echo "✅ Ollama running with model: $MODEL"
else
    echo "⚠️  Ollama not running (optional but recommended)"
    echo "   Start with: ollama serve"
fi

# 2. Check OpenTelemetry Collector
if curl -s http://localhost:4318/health >/dev/null 2>&1; then
    echo "✅ OpenTelemetry Collector running"
else
    echo "⚠️  OTel Collector not running"
    echo "   Start with: ./telemetry/start_collector.sh"
fi

# 3. Make all scripts executable
echo ""
echo "Setting up automation scripts..."
chmod +x automation/*.sh telemetry/*.sh

# Create cron entries
echo ""
echo "📅 Cron Schedule:"
echo "=================="
cat << 'EOF'
# CDCS Autonomous System
*/5 * * * *  /Users/sac/claude-desktop-context/automation/autonomous_loop.sh
*/10 * * * * /Users/sac/claude-desktop-context/automation/telemetry_analyzer_v2.sh
0 * * * *    /Users/sac/claude-desktop-context/automation/pattern_refresher.sh
0 3 * * *    /Users/sac/claude-desktop-context/automation/cleanup.sh
EOF

echo ""
echo "Current cron jobs:"
crontab -l 2>/dev/null | grep "claude-desktop-context" || echo "  None installed"

echo ""
read -p "Install autonomous cron jobs? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Backup existing crontab
    crontab -l > /tmp/cron_backup_$$ 2>/dev/null || true
    
    # Add our jobs
    (
        crontab -l 2>/dev/null | grep -v "claude-desktop-context/automation"
        echo "# CDCS Autonomous System"
        echo "*/5 * * * * /Users/sac/claude-desktop-context/automation/autonomous_loop.sh >> /Users/sac/claude-desktop-context/automation/cron.log 2>&1"
        echo "*/10 * * * * /Users/sac/claude-desktop-context/automation/telemetry_analyzer_v2.sh >> /Users/sac/claude-desktop-context/automation/cron.log 2>&1"
        echo "0 * * * * /Users/sac/claude-desktop-context/automation/pattern_refresher.sh >> /Users/sac/claude-desktop-context/automation/cron.log 2>&1"
        echo "0 3 * * * /Users/sac/claude-desktop-context/automation/cleanup.sh >> /Users/sac/claude-desktop-context/automation/cron.log 2>&1"
    ) | crontab -
    
    echo "✅ Cron jobs installed!"
fi

echo ""
echo "📊 Monitoring Commands:"
echo "======================"
echo ""
echo "Watch real-time activity:"
echo "  ./telemetry/trace_flow_monitor.sh"
echo ""
echo "View dashboard:"
echo "  ./telemetry/claude_dashboard.sh"
echo ""
echo "Check system status:"
echo "  ./telemetry/claude_quick_status.sh"
echo ""
echo "View automation log:"
echo "  tail -f automation/autonomous.log"
echo ""
echo "See AI suggestions:"
echo "  tail insights/ai_suggestions.log"
echo ""
echo "Monitor work queue:"
echo "  watch -n 5 'jq . work/work_claims.json'"
echo ""

# Run initial analysis
echo "🚀 Running initial analysis..."
./automation/autonomous_loop.sh

echo ""
echo "✅ Autonomous CDCS system is ready!"
echo ""
echo "The system will now:"
echo "• Run every 5 minutes automatically"
echo "• Monitor and analyze all telemetry"
echo "• Create work items for optimization"
echo "• Self-heal when issues arise"
echo "• Learn and improve over time"
echo ""
echo "🧠 + 🤖 = 🚀"
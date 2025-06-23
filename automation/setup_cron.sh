#!/bin/bash
# CDCS Automation Setup Script
# Configures cron jobs for 24/7 CDCS enhancement using ollama

CDCS_PATH="/Users/sac/claude-desktop-context"
AUTOMATION_PATH="$CDCS_PATH/automation"
PYTHON_PATH="/usr/bin/python3"
LOG_PATH="$AUTOMATION_PATH/logs"

# Create log directory
mkdir -p "$LOG_PATH"

# Function to add cron job if not exists
add_cron_job() {
    local schedule="$1"
    local command="$2"
    local job_id="$3"
    
    # Check if job already exists
    if ! crontab -l 2>/dev/null | grep -q "$job_id"; then
        # Add the job
        (crontab -l 2>/dev/null; echo "$schedule $command # $job_id") | crontab -
        echo "Added cron job: $job_id"
    else
        echo "Cron job already exists: $job_id"
    fi
}

# Main orchestrator - runs every hour
add_cron_job \
    "0 * * * *" \
    "$PYTHON_PATH $AUTOMATION_PATH/cdcs_orchestrator.py >> $LOG_PATH/orchestrator.log 2>&1" \
    "CDCS_ORCHESTRATOR"

# Pattern mining - runs every 4 hours (high activity times)
add_cron_job \
    "0 */4 * * *" \
    "$PYTHON_PATH -c 'from automation.agents.pattern_miner import PatternMiner; from automation.cdcs_orchestrator import CDCSOrchestrator; o=CDCSOrchestrator(); PatternMiner(o).run()' >> $LOG_PATH/pattern_miner.log 2>&1" \
    "CDCS_PATTERN_MINER"

# Memory optimization - runs daily at 2 AM
add_cron_job \
    "0 2 * * *" \
    "$PYTHON_PATH -c 'from automation.agents.memory_optimizer import MemoryOptimizer; from automation.cdcs_orchestrator import CDCSOrchestrator; o=CDCSOrchestrator(); MemoryOptimizer(o).run()' >> $LOG_PATH/memory_optimizer.log 2>&1" \
    "CDCS_MEMORY_OPTIMIZER"

# Knowledge synthesis - runs weekly on Sundays at 3 AM
add_cron_job \
    "0 3 * * 0" \
    "$PYTHON_PATH -c 'from automation.agents.knowledge_synthesizer import KnowledgeSynthesizer; from automation.cdcs_orchestrator import CDCSOrchestrator; o=CDCSOrchestrator(); KnowledgeSynthesizer(o).run()' >> $LOG_PATH/knowledge_synthesizer.log 2>&1" \
    "CDCS_KNOWLEDGE_SYNTHESIZER"

# Evolution hunter - runs every 6 hours
add_cron_job \
    "0 */6 * * *" \
    "$PYTHON_PATH -c 'from automation.agents.evolution_hunter import EvolutionHunter; from automation.cdcs_orchestrator import CDCSOrchestrator; o=CDCSOrchestrator(); EvolutionHunter(o).run()' >> $LOG_PATH/evolution_hunter.log 2>&1" \
    "CDCS_EVOLUTION_HUNTER"

# Predictive loader - runs every 30 minutes during work hours
add_cron_job \
    "*/30 8-18 * * 1-5" \
    "$PYTHON_PATH -c 'from automation.agents.predictive_loader import PredictiveLoader; from automation.cdcs_orchestrator import CDCSOrchestrator; o=CDCSOrchestrator(); PredictiveLoader(o).run()' >> $LOG_PATH/predictive_loader.log 2>&1" \
    "CDCS_PREDICTIVE_LOADER"

# System health monitor - runs every 2 hours
add_cron_job \
    "0 */2 * * *" \
    "$PYTHON_PATH -c 'from automation.agents.system_health_monitor import SystemHealthMonitor; from automation.cdcs_orchestrator import CDCSOrchestrator; o=CDCSOrchestrator(); SystemHealthMonitor(o).run()' >> $LOG_PATH/system_health_monitor.log 2>&1" \
    "CDCS_HEALTH_MONITOR"

# Quick pattern cache refresh - runs every 15 minutes
add_cron_job \
    "*/15 * * * *" \
    "$PYTHON_PATH -c 'import json; from pathlib import Path; p=Path(\"/Users/sac/claude-desktop-context/patterns/cache\"); p.mkdir(exist_ok=True); (p/\"last_refresh.txt\").write_text(str(__import__(\"datetime\").datetime.now()))' >> $LOG_PATH/cache_refresh.log 2>&1" \
    "CDCS_CACHE_REFRESH"

# Log rotation - runs daily at midnight
add_cron_job \
    "0 0 * * *" \
    "find $LOG_PATH -name '*.log' -size +100M -exec mv {} {}.old \; && find $LOG_PATH -name '*.log.old' -mtime +7 -delete" \
    "CDCS_LOG_ROTATION"

echo ""
echo "CDCS 24/7 Automation Setup Complete!"
echo ""
echo "Cron jobs installed:"
crontab -l | grep "CDCS_"
echo ""
echo "To monitor automation:"
echo "  tail -f $LOG_PATH/orchestrator.log"
echo ""
echo "To check automation status:"
echo "  $PYTHON_PATH $AUTOMATION_PATH/check_status.py"
echo ""
echo "To disable automation:"
echo "  $AUTOMATION_PATH/disable_cron.sh"

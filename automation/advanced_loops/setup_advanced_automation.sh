#!/bin/bash
# Advanced Automation Loops - Master Setup Script
# Integrates all advanced automation capabilities into CDCS

CDCS_PATH="/Users/sac/claude-desktop-context"
AUTOMATION_PATH="$CDCS_PATH/automation"
ADVANCED_PATH="$AUTOMATION_PATH/advanced_loops"
PYTHON_PATH="/usr/bin/python3"

echo "🚀 Setting up Advanced CDCS Automation Loops"
echo "==========================================="

# Ensure Python dependencies
echo "📦 Checking Python dependencies..."
pip3 install psutil fsevents 2>/dev/null || echo "Some optional dependencies may be missing"

# Create necessary directories
echo "📁 Creating directory structure..."
mkdir -p "$ADVANCED_PATH/rules"
mkdir -p "$ADVANCED_PATH/discovered_patterns"
mkdir -p "$ADVANCED_PATH/reports"
mkdir -p "$AUTOMATION_PATH/hot_reload"
mkdir -p "$AUTOMATION_PATH/batch_scripts"
mkdir -p "$AUTOMATION_PATH/workflow_optimizations"
mkdir -p "$AUTOMATION_PATH/error_investigations"

# Create default automation rules
echo "📝 Creating default automation rules..."
cat > "$ADVANCED_PATH/rules/default_rules.json" << 'EOF'
{
  "terminal_orchestration": {
    "enabled": true,
    "max_parallel_sessions": 10,
    "patterns": {
      "batch_processing": {
        "trigger": "multiple similar commands",
        "threshold": 5,
        "action": "create_parallel_batch"
      }
    }
  },
  "realtime_monitoring": {
    "enabled": true,
    "monitored_paths": [
      "/Users/sac/claude-desktop-context",
      "~/Desktop",
      "~/Documents"
    ],
    "triggers": {
      "rapid_changes": {
        "threshold_per_minute": 5,
        "action": "enable_hot_reload"
      },
      "bulk_operations": {
        "threshold": 20,
        "window_seconds": 10,
        "action": "suggest_batch_script"
      }
    }
  },
  "intelligent_scheduling": {
    "enabled": true,
    "optimization_threshold": 20,
    "metrics_window_days": 7,
    "auto_adjust": false
  },
  "self_healing": {
    "enabled": true,
    "auto_fix": true,
    "severity_levels": {
      "critical": {
        "auto_fix": true,
        "notify": true
      },
      "high": {
        "auto_fix": true,
        "notify": false
      },
      "medium": {
        "auto_fix": false,
        "notify": false
      },
      "low": {
        "auto_fix": false,
        "notify": false
      }
    }
  }
}
EOF

# Add advanced loops to cron
echo "⏰ Setting up advanced cron jobs..."

add_cron_job() {
    local schedule="$1"
    local command="$2"
    local job_id="$3"
    
    # Check if job already exists
    if crontab -l 2>/dev/null | grep -q "$job_id"; then
        echo "   ✓ $job_id already scheduled"
    else
        # Add the job
        (crontab -l 2>/dev/null; echo "$schedule $command # $job_id") | crontab -
        echo "   ✓ Added $job_id"
    fi
}

# Terminal Orchestrator - runs every 2 hours for complex task detection
add_cron_job \
    "0 */2 * * *" \
    "$PYTHON_PATH $ADVANCED_PATH/terminal_orchestrator.py >> $AUTOMATION_PATH/logs/terminal_orchestrator.log 2>&1" \
    "CDCS_TERMINAL_ORCHESTRATOR"

# Realtime Pattern Detector - runs every 30 minutes during work hours
add_cron_job \
    "*/30 8-20 * * *" \
    "$PYTHON_PATH $ADVANCED_PATH/realtime_pattern_detector.py >> $AUTOMATION_PATH/logs/realtime_detector.log 2>&1" \
    "CDCS_REALTIME_DETECTOR"

# Intelligent Cron Scheduler - runs daily at 4 AM for schedule optimization
add_cron_job \
    "0 4 * * *" \
    "$PYTHON_PATH $ADVANCED_PATH/intelligent_cron_scheduler.py >> $AUTOMATION_PATH/logs/cron_scheduler.log 2>&1" \
    "CDCS_CRON_OPTIMIZER"

# Self-Healing Loop - runs every hour for system health
add_cron_job \
    "30 * * * *" \
    "$PYTHON_PATH $ADVANCED_PATH/self_healing_loop.py >> $AUTOMATION_PATH/logs/self_healing.log 2>&1" \
    "CDCS_SELF_HEALING"

# Create systemd-style service for continuous monitoring (optional)
echo "🔧 Creating optional systemd service..."
cat > "$ADVANCED_PATH/cdcs-monitor.service" << EOF
[Unit]
Description=CDCS Advanced Monitoring Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$ADVANCED_PATH
ExecStart=$PYTHON_PATH -u $ADVANCED_PATH/realtime_pattern_detector.py --continuous
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create monitoring dashboard script
echo "📊 Creating monitoring dashboard..."
cat > "$ADVANCED_PATH/monitor_dashboard.sh" << 'EOF'
#!/bin/bash
# CDCS Advanced Automation Monitoring Dashboard

CDCS_PATH="/Users/sac/claude-desktop-context"
AUTOMATION_PATH="$CDCS_PATH/automation"
ADVANCED_PATH="$AUTOMATION_PATH/advanced_loops"

clear
echo "CDCS Advanced Automation Dashboard"
echo "================================="
echo ""

# Check running processes
echo "🔄 Active Automation Processes:"
ps aux | grep -E "(terminal_orchestrator|realtime_pattern|intelligent_cron|self_healing)" | grep -v grep | wc -l | xargs echo "   Running:"

echo ""
echo "📈 Recent Activity (last hour):"
find "$AUTOMATION_PATH/logs" -name "*.log" -mmin -60 -exec wc -l {} \; | awk '{total += $1} END {print "   Log entries: " total}'

echo ""
echo "🩺 System Health:"
if [ -f "$AUTOMATION_PATH/reports/health_report_*.md" ]; then
    latest_health=$(ls -t "$AUTOMATION_PATH/reports"/health_report_*.md | head -1)
    grep -E "(No active issues|active issues)" "$latest_health" | head -1 | xargs echo "   Status:"
fi

echo ""
echo "🎯 Detected Patterns (last 24h):"
pattern_count=$(find "$ADVANCED_PATH/discovered_patterns" -name "*.md" -mtime -1 | wc -l)
echo "   New patterns: $pattern_count"

echo ""
echo "⚡ Automation Triggers (today):"
if [ -f "$AUTOMATION_PATH/logs/automation_events.jsonl" ]; then
    today_count=$(grep "$(date +%Y-%m-%d)" "$AUTOMATION_PATH/logs/automation_events.jsonl" 2>/dev/null | wc -l)
    echo "   Triggered: $today_count"
fi

echo ""
echo "📋 Recent Logs:"
echo "   Terminal Orchestrator:"
tail -3 "$AUTOMATION_PATH/logs/terminal_orchestrator.log" 2>/dev/null | sed 's/^/      /'
echo "   Pattern Detector:"
tail -3 "$AUTOMATION_PATH/logs/realtime_detector.log" 2>/dev/null | sed 's/^/      /'
echo "   Self-Healing:"
tail -3 "$AUTOMATION_PATH/logs/self_healing.log" 2>/dev/null | sed 's/^/      /'

echo ""
echo "Press Ctrl+C to exit, refreshing every 10 seconds..."
EOF

chmod +x "$ADVANCED_PATH/monitor_dashboard.sh"

# Create manual trigger script
echo "🎮 Creating manual trigger controls..."
cat > "$ADVANCED_PATH/manual_trigger.sh" << 'EOF'
#!/bin/bash
# Manually trigger advanced automation loops

CDCS_PATH="/Users/sac/claude-desktop-context"
ADVANCED_PATH="$CDCS_PATH/automation/advanced_loops"
PYTHON_PATH="/usr/bin/python3"

echo "CDCS Advanced Automation - Manual Trigger"
echo "========================================"
echo ""
echo "Select component to run:"
echo "1) Terminal Orchestrator"
echo "2) Realtime Pattern Detector"
echo "3) Intelligent Cron Scheduler"
echo "4) Self-Healing Loop"
echo "5) Run All"
echo ""
read -p "Enter choice (1-5): " choice

case $choice in
    1)
        echo "Running Terminal Orchestrator..."
        $PYTHON_PATH "$ADVANCED_PATH/terminal_orchestrator.py"
        ;;
    2)
        echo "Running Realtime Pattern Detector..."
        $PYTHON_PATH "$ADVANCED_PATH/realtime_pattern_detector.py"
        ;;
    3)
        echo "Running Intelligent Cron Scheduler..."
        $PYTHON_PATH "$ADVANCED_PATH/intelligent_cron_scheduler.py"
        ;;
    4)
        echo "Running Self-Healing Loop..."
        $PYTHON_PATH "$ADVANCED_PATH/self_healing_loop.py"
        ;;
    5)
        echo "Running all components..."
        $PYTHON_PATH "$ADVANCED_PATH/terminal_orchestrator.py" &
        $PYTHON_PATH "$ADVANCED_PATH/realtime_pattern_detector.py" &
        $PYTHON_PATH "$ADVANCED_PATH/intelligent_cron_scheduler.py" &
        $PYTHON_PATH "$ADVANCED_PATH/self_healing_loop.py" &
        wait
        ;;
    *)
        echo "Invalid choice"
        ;;
esac
EOF

chmod +x "$ADVANCED_PATH/manual_trigger.sh"

echo ""
echo "✅ Advanced Automation Setup Complete!"
echo ""
echo "📚 Components Installed:"
echo "   • Terminal Orchestrator - Manages parallel terminal sessions"
echo "   • Realtime Pattern Detector - Monitors file system for patterns"
echo "   • Intelligent Cron Scheduler - Optimizes job scheduling"
echo "   • Self-Healing Loop - Detects and fixes system issues"
echo ""
echo "🎯 Quick Commands:"
echo "   Monitor: $ADVANCED_PATH/monitor_dashboard.sh"
echo "   Trigger: $ADVANCED_PATH/manual_trigger.sh"
echo "   Logs:    tail -f $AUTOMATION_PATH/logs/*.log"
echo "   Status:  python3 $AUTOMATION_PATH/check_status.py"
echo ""
echo "⚙️ Configuration:"
echo "   Rules: $ADVANCED_PATH/rules/default_rules.json"
echo "   Edit rules to customize automation behavior"
echo ""
echo "🚀 The system is now learning and adapting continuously!"

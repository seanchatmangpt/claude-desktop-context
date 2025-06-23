#!/bin/bash

##############################################################################
# CDCS Cron Manager
# Sets up and manages automated tasks that run independently
##############################################################################

CDCS_HOME="/Users/sac/claude-desktop-context"
CRON_LOG="$CDCS_HOME/automation/cron.log"

# Ensure directories exist
mkdir -p "$CDCS_HOME/automation/logs"

echo "🤖 CDCS Cron Manager"
echo "==================="
echo ""

# Function to add cron job
add_cron_job() {
    local schedule="$1"
    local command="$2"
    local description="$3"
    
    # Check if job already exists
    if crontab -l 2>/dev/null | grep -q "$command"; then
        echo "⚠️  Job already exists: $description"
        return
    fi
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$schedule $command >> $CRON_LOG 2>&1") | crontab -
    echo "✅ Added: $description"
}

# Function to setup all CDCS cron jobs
setup_cron_jobs() {
    echo "Setting up automated tasks..."
    echo ""
    
    # 1. Telemetry Analysis (every 5 minutes)
    add_cron_job "*/5 * * * *" \
        "$CDCS_HOME/automation/telemetry_analyzer.sh" \
        "Telemetry analysis with Ollama"
    
    # 2. Pattern Recognition Refresh (every hour)
    add_cron_job "0 * * * *" \
        "$CDCS_HOME/automation/pattern_refresher.sh" \
        "Pattern cache refresh"
    
    # 3. Memory Consolidation (daily at 2 AM)
    add_cron_job "0 2 * * *" \
        "$CDCS_HOME/automation/memory_consolidator.sh" \
        "Memory consolidation"
    
    # 4. Health Check (every minute)
    add_cron_job "* * * * *" \
        "$CDCS_HOME/automation/health_checker.sh" \
        "System health monitoring"
    
    # 5. Work Queue Processor (every 10 minutes)
    add_cron_job "*/10 * * * *" \
        "$CDCS_HOME/automation/work_processor.sh" \
        "Process work queue with AI"
    
    # 6. Trace Cleanup (daily at 3 AM)
    add_cron_job "0 3 * * *" \
        "$CDCS_HOME/automation/cleanup.sh" \
        "Clean old traces and logs"
}

# Create the automation scripts

# 1. Pattern Refresher
cat > "$CDCS_HOME/automation/pattern_refresher.sh" << 'EOF'
#!/bin/bash
# Refresh pattern recognition cache

PATTERNS_DIR="/Users/sac/claude-desktop-context/patterns"
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"

echo "[$(date)] Refreshing pattern cache..."

# Analyze recent patterns
recent_patterns=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -60 -exec cat {} \; 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' | \
    sort | uniq -c | sort -nr | head -20)

# Save to pattern cache
echo "$recent_patterns" > "$PATTERNS_DIR/cache/recent_patterns.txt"
date > "$PATTERNS_DIR/cache/last_refresh.txt"

# Use Ollama to identify new patterns
prompt="Analyze these operation patterns and identify any new or emerging patterns:
$recent_patterns

Output as JSON with keys: new_patterns, trending_up, trending_down"

curl -s http://localhost:11434/api/generate \
    -d "{\"model\": \"llama3.2\", \"prompt\": \"$prompt\", \"stream\": false, \"format\": \"json\"}" | \
    jq -r '.response' > "$PATTERNS_DIR/cache/pattern_analysis.json"

echo "[$(date)] Pattern refresh complete"
EOF

# 2. Memory Consolidator
cat > "$CDCS_HOME/automation/memory_consolidator.sh" << 'EOF'
#!/bin/bash
# Consolidate and compress memory sessions

MEMORY_DIR="/Users/sac/claude-desktop-context/memory"
INSIGHTS_DIR="/Users/sac/claude-desktop-context/insights"

echo "[$(date)] Starting memory consolidation..."

# Find sessions older than 7 days
old_sessions=$(find "$MEMORY_DIR/sessions" -name "*.md" -mtime +7)

if [[ -n "$old_sessions" ]]; then
    # Create consolidation summary
    summary_file="$MEMORY_DIR/consolidated/summary_$(date +%Y%m%d).md"
    mkdir -p "$MEMORY_DIR/consolidated"
    
    echo "# Memory Consolidation Summary" > "$summary_file"
    echo "Generated: $(date)" >> "$summary_file"
    echo "" >> "$summary_file"
    
    # Process each old session
    echo "$old_sessions" | while read -r session; do
        content=$(cat "$session")
        
        # Use Ollama to summarize
        prompt="Summarize this session content in 2-3 key points:
$content"
        
        summary=$(curl -s http://localhost:11434/api/generate \
            -d "{\"model\": \"llama3.2\", \"prompt\": \"$prompt\", \"stream\": false}" | \
            jq -r '.response')
        
        echo "## $(basename "$session")" >> "$summary_file"
        echo "$summary" >> "$summary_file"
        echo "" >> "$summary_file"
        
        # Archive the original
        mv "$session" "$MEMORY_DIR/archived/"
    done
fi

echo "[$(date)] Memory consolidation complete"
EOF

# 3. Health Checker
cat > "$CDCS_HOME/automation/health_checker.sh" << 'EOF'
#!/bin/bash
# Quick health check that runs every minute

CDCS_HOME="/Users/sac/claude-desktop-context"
HEALTH_FILE="$CDCS_HOME/automation/health_status.json"

# Check collector
collector_status="down"
curl -s http://localhost:4318/health >/dev/null 2>&1 && collector_status="up"

# Count recent errors
errors=$(find "$CDCS_HOME/telemetry/logs" -name "*.jsonl" -mmin -5 -exec grep -ci error {} \; 2>/dev/null | \
    awk '{s+=$1} END {print s}')

# Check disk space
disk_usage=$(df -h "$CDCS_HOME" | tail -1 | awk '{print $5}' | sed 's/%//')

# Create health report
cat > "$HEALTH_FILE" << JSON
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "collector": "$collector_status",
    "recent_errors": ${errors:-0},
    "disk_usage_percent": $disk_usage,
    "status": "$(if [[ $errors -gt 10 ]] || [[ $disk_usage -gt 90 ]]; then echo "warning"; else echo "healthy"; fi)"
}
JSON

# Alert on critical conditions
if [[ $errors -gt 50 ]] || [[ $disk_usage -gt 95 ]]; then
    echo "[$(date)] CRITICAL: Errors=$errors, Disk=$disk_usage%" >> "$CDCS_HOME/automation/alerts.log"
fi
EOF

# 4. Work Processor
cat > "$CDCS_HOME/automation/work_processor.sh" << 'EOF'
#!/bin/bash
# Process work queue items with AI assistance

WORK_DIR="/Users/sac/claude-desktop-context/work"
WORK_FILE="$WORK_DIR/work_claims.json"

if [[ ! -f "$WORK_FILE" ]]; then
    exit 0
fi

echo "[$(date)] Processing work queue..."

# Get uncompleted work items
jq -r '.[] | select(.status != "completed") | @json' "$WORK_FILE" 2>/dev/null | while read -r work_item; do
    work_id=$(echo "$work_item" | jq -r '.id')
    work_type=$(echo "$work_item" | jq -r '.type')
    description=$(echo "$work_item" | jq -r '.description')
    
    # Skip if recently updated
    last_update=$(echo "$work_item" | jq -r '.last_update // ""')
    if [[ -n "$last_update" ]]; then
        update_age=$(( $(date +%s) - $(date -d "$last_update" +%s 2>/dev/null || echo 0) ))
        [[ $update_age -lt 300 ]] && continue
    fi
    
    # Process based on type
    case "$work_type" in
        "performance_optimization")
            # Analyze and suggest optimizations
            prompt="Provide specific implementation steps for: $description"
            ;;
        "self_improvement")
            # Generate improvement plan
            prompt="Create actionable plan for: $description"
            ;;
        *)
            # Generic processing
            prompt="How to implement: $description"
            ;;
    esac
    
    # Get AI recommendation
    recommendation=$(curl -s http://localhost:11434/api/generate \
        -d "{\"model\": \"llama3.2\", \"prompt\": \"$prompt\", \"stream\": false}" | \
        jq -r '.response' | head -100)
    
    # Update work item with progress
    /Users/sac/claude-desktop-context/coordination_helper_v2.sh update "$work_id" "25" "$recommendation"
done

echo "[$(date)] Work processing complete"
EOF

# 5. Cleanup Script
cat > "$CDCS_HOME/automation/cleanup.sh" << 'EOF'
#!/bin/bash
# Clean up old files to prevent disk bloat

CDCS_HOME="/Users/sac/claude-desktop-context"

echo "[$(date)] Starting cleanup..."

# Remove old traces (>14 days)
find "$CDCS_HOME/telemetry/data" -name "*.jsonl" -mtime +14 -delete

# Remove old logs (>30 days)
find "$CDCS_HOME/telemetry/logs" -name "*.jsonl" -mtime +30 -delete

# Compress old insights (>7 days)
find "$CDCS_HOME/insights" -name "*.json" -mtime +7 -exec gzip {} \;

# Clean empty directories
find "$CDCS_HOME" -type d -empty -delete

# Log cleanup stats
echo "[$(date)] Cleanup complete. Disk usage: $(du -sh "$CDCS_HOME" | awk '{print $1}')"
EOF

# Make all scripts executable
chmod +x "$CDCS_HOME/automation/"*.sh

# Show current crontab
echo ""
echo "Current cron jobs:"
echo "=================="
crontab -l 2>/dev/null || echo "No cron jobs configured"

# Ask to install
echo ""
echo "Ready to install CDCS automation cron jobs."
echo "These will run independently and continuously analyze your system."
echo ""
read -p "Install cron jobs? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    setup_cron_jobs
    echo ""
    echo "✅ Automation installed!"
    echo ""
    echo "Monitor activity:"
    echo "  tail -f $CRON_LOG"
    echo ""
    echo "View insights:"
    echo "  ls -la $CDCS_HOME/insights/"
    echo ""
    echo "Check health:"
    echo "  cat $CDCS_HOME/automation/health_status.json"
else
    echo "ℹ️  Installation skipped. Run this script again to install."
fi
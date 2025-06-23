#!/bin/bash

##############################################################################
# CDCS Autonomous Loop - Runs continuously via cron
# Monitors, analyzes, and self-improves using OpenTelemetry data
##############################################################################

CDCS_HOME="/Users/sac/claude-desktop-context"
LOG_FILE="$CDCS_HOME/automation/autonomous.log"

# Log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Rotate logs if too large
if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt 10485760 ]]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
fi

log "=== Starting Autonomous Loop ==="

# 1. Collect system metrics
log "Collecting metrics..."

TRACE_COUNT=$(find "$CDCS_HOME/telemetry/data" -name "*.jsonl" -mmin -5 -exec cat {} \; 2>/dev/null | wc -l)
ERROR_COUNT=$(find "$CDCS_HOME/telemetry/logs" -name "*.jsonl" -mmin -5 -exec grep -ci error {} \; 2>/dev/null | awk '{s+=$1} END {print s+0}')
WORK_QUEUE=$(jq -r 'map(select(.status != "completed")) | length' "$CDCS_HOME/work/work_claims.json" 2>/dev/null || echo 0)

log "Metrics: $TRACE_COUNT traces, $ERROR_COUNT errors, $WORK_QUEUE pending work items"

# 2. Pattern analysis
log "Analyzing patterns..."

FREQUENT_OPS=$(find "$CDCS_HOME/telemetry/data" -name "*.jsonl" -mmin -60 -exec cat {} \; 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' 2>/dev/null | \
    sort | uniq -c | sort -nr | head -3)

if [[ -n "$FREQUENT_OPS" ]]; then
    while IFS= read -r op; do
        count=$(echo "$op" | awk '{print $1}')
        name=$(echo "$op" | awk '{$1=""; print $0}' | sed 's/^ //')
        
        # If operation is too frequent, create optimization task
        if [[ $count -gt 50 ]]; then
            log "High frequency operation detected: $name ($count times)"
            
            # Check if we already have a task for this
            existing=$(jq -r --arg op "$name" '.[] | select(.description | contains($op)) | .id' \
                "$CDCS_HOME/work/work_claims.json" 2>/dev/null)
            
            if [[ -z "$existing" ]]; then
                log "Creating optimization task for $name"
                "$CDCS_HOME/coordination_helper_v2.sh" claim "auto_optimize" \
                    "Optimize high-frequency operation: $name" "medium" >/dev/null 2>&1
            fi
        fi
    done <<< "$FREQUENT_OPS"
fi

# 3. Error monitoring and self-healing
if [[ $ERROR_COUNT -gt 5 ]]; then
    log "ERROR: High error rate detected ($ERROR_COUNT errors)"
    
    # Get most common error
    TOP_ERROR=$(find "$CDCS_HOME/telemetry/logs" -name "*.jsonl" -mmin -60 -exec grep -i error {} \; 2>/dev/null | \
        jq -r '.message' 2>/dev/null | sort | uniq -c | sort -nr | head -1)
    
    if [[ -n "$TOP_ERROR" ]]; then
        error_msg=$(echo "$TOP_ERROR" | awk '{$1=""; print $0}' | sed 's/^ //')
        log "Most common error: $error_msg"
        
        # Create self-healing task
        "$CDCS_HOME/coordination_helper_v2.sh" claim "self_healing" \
            "Fix recurring error: $error_msg" "high" >/dev/null 2>&1
    fi
fi

# 4. Performance monitoring
log "Checking performance..."

SLOW_COUNT=$(find "$CDCS_HOME/telemetry/data" -name "*.jsonl" -mmin -30 -exec cat {} \; 2>/dev/null | \
    jq -r 'select(.resourceSpans[0].scopeSpans[0].spans[0].endTimeUnixNano != null) | 
    .resourceSpans[0].scopeSpans[0].spans[0] | 
    ((.endTimeUnixNano | tonumber) - (.startTimeUnixNano | tonumber)) / 1000000' 2>/dev/null | \
    awk '$1 > 500 {count++} END {print count+0}')

if [[ $SLOW_COUNT -gt 10 ]]; then
    log "WARNING: $SLOW_COUNT slow operations detected (>500ms)"
    
    # Find slowest operation
    SLOWEST=$(find "$CDCS_HOME/telemetry/data" -name "*.jsonl" -mmin -30 -exec cat {} \; 2>/dev/null | \
        jq -r 'select(.resourceSpans[0].scopeSpans[0].spans[0].endTimeUnixNano != null) | 
        .resourceSpans[0].scopeSpans[0].spans[0] | 
        "\(((.endTimeUnixNano | tonumber) - (.startTimeUnixNano | tonumber)) / 1000000)||\(.name)"' 2>/dev/null | \
        sort -t'|' -k1 -nr | head -1)
    
    if [[ -n "$SLOWEST" ]]; then
        duration=$(echo "$SLOWEST" | cut -d'|' -f1)
        operation=$(echo "$SLOWEST" | cut -d'|' -f3)
        log "Slowest operation: $operation (${duration}ms)"
    fi
fi

# 5. Work queue processing
if [[ $WORK_QUEUE -gt 0 ]]; then
    log "Processing $WORK_QUEUE work items..."
    
    # Process oldest unstarted work item
    OLDEST_WORK=$(jq -r '.[] | select(.status == "claimed" and .progress == null) | .id' \
        "$CDCS_HOME/work/work_claims.json" 2>/dev/null | head -1)
    
    if [[ -n "$OLDEST_WORK" ]]; then
        log "Starting work on: $OLDEST_WORK"
        "$CDCS_HOME/coordination_helper_v2.sh" update "$OLDEST_WORK" "10" "Started by autonomous system" >/dev/null 2>&1
    fi
fi

# 6. Health score calculation
HEALTH=100
HEALTH=$((HEALTH - ERROR_COUNT * 2))
HEALTH=$((HEALTH - SLOW_COUNT))
HEALTH=$((HEALTH - (WORK_QUEUE > 10 ? 10 : 0)))
[[ $HEALTH -lt 0 ]] && HEALTH=0

log "System health: $HEALTH/100"

# Save health metric
echo "{\"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"health\": $HEALTH, \"traces\": $TRACE_COUNT, \"errors\": $ERROR_COUNT}" >> \
    "$CDCS_HOME/insights/autonomous_metrics.jsonl"

# 7. Ollama integration (if available)
if command -v curl >/dev/null && curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    log "Using Ollama for intelligent analysis..."
    
    # Get model
    MODEL=$(curl -s http://localhost:11434/api/tags 2>/dev/null | jq -r '.models[0].name // "qwen3"')
    
    # Create analysis prompt
    PROMPT="System metrics: $TRACE_COUNT traces, $ERROR_COUNT errors, $WORK_QUEUE tasks, health $HEALTH/100. Suggest one improvement in 10 words."
    
    # Get suggestion
    SUGGESTION=$(curl -s -X POST http://localhost:11434/api/generate \
        -d "{\"model\": \"$MODEL\", \"prompt\": \"$PROMPT\", \"stream\": false}" 2>/dev/null | \
        jq -r '.response // empty' | \
        sed -n '/<think>/,/<\/think>/!p' | \
        grep -v '^$' | \
        head -1)
    
    if [[ -n "$SUGGESTION" ]]; then
        log "AI suggestion: $SUGGESTION"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $SUGGESTION" >> "$CDCS_HOME/insights/ai_suggestions.log"
    fi
fi

# 8. Cleanup old data (if needed)
DISK_USAGE=$(df -h "$CDCS_HOME" | tail -1 | awk '{print $5}' | sed 's/%//')
if [[ $DISK_USAGE -gt 80 ]]; then
    log "WARNING: Disk usage at ${DISK_USAGE}%, running cleanup..."
    
    # Remove traces older than 7 days
    find "$CDCS_HOME/telemetry/data" -name "*.jsonl" -mtime +7 -delete
    find "$CDCS_HOME/telemetry/logs" -name "*.jsonl" -mtime +14 -delete
    
    log "Cleanup complete"
fi

# 9. Self-improvement check
if [[ $HEALTH -lt 50 ]]; then
    log "CRITICAL: Low health score, initiating self-improvement..."
    
    # Create high-priority improvement task
    "$CDCS_HOME/coordination_helper_v2.sh" claim "critical_improvement" \
        "System health critical ($HEALTH/100) - investigate and fix" "critical" >/dev/null 2>&1
fi

log "=== Autonomous Loop Complete ==="
log "Next run in 5 minutes via cron"
echo ""

# Show quick summary if run manually
if [[ -t 1 ]]; then
    echo "📊 Quick Summary:"
    echo "  Health: $HEALTH/100"
    echo "  Traces: $TRACE_COUNT (5 min)"
    echo "  Errors: $ERROR_COUNT"
    echo "  Tasks: $WORK_QUEUE pending"
    echo ""
    echo "See full log: tail -f $LOG_FILE"
fi
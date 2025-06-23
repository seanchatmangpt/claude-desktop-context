#!/bin/bash

##############################################################################
# Telemetry Analyzer v2 - Pure Shell with Ollama
##############################################################################

CDCS_HOME="/Users/sac/claude-desktop-context"
TELEMETRY_DIR="$CDCS_HOME/telemetry"
INSIGHTS_DIR="$CDCS_HOME/insights"

# Source Ollama helper
source "$CDCS_HOME/automation/ollama_helper.sh"

# Create directories
mkdir -p "$INSIGHTS_DIR"/{patterns,anomalies,recommendations}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting telemetry analysis..."

# 1. Analyze trace patterns
echo "Analyzing trace patterns..."

PATTERNS=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -60 -exec cat {} \; 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' 2>/dev/null | \
    sort | uniq -c | sort -nr | head -10 | \
    awk '{printf "%d %s\n", $1, $2}')

if [[ -n "$PATTERNS" ]]; then
    echo "Found patterns:"
    echo "$PATTERNS"
    
    # Get AI analysis
    ANALYSIS=$(analyze_patterns "$PATTERNS")
    
    if [[ -n "$ANALYSIS" ]]; then
        echo "AI Recommendation: $ANALYSIS"
        
        # Save recommendation
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $ANALYSIS" >> "$INSIGHTS_DIR/recommendations/latest.txt"
        
        # Create work item if significant
        if echo "$PATTERNS" | awk '$1 > 10 {exit 0} {exit 1}'; then
            echo "Creating optimization work item..."
            "$CDCS_HOME/coordination_helper_v2.sh" claim "optimization" "$ANALYSIS" "medium"
        fi
    fi
fi

# 2. Detect anomalies
echo ""
echo "Checking for anomalies..."

ERROR_COUNT=$(find "$TELEMETRY_DIR/logs" -name "*.jsonl" -mmin -60 -exec grep -ci error {} \; 2>/dev/null | \
    awk '{s+=$1} END {print s+0}')
TRACE_COUNT=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -60 -exec cat {} \; 2>/dev/null | wc -l)

echo "Last hour: $ERROR_COUNT errors, $TRACE_COUNT traces"

# Get health assessment
HEALTH=$(assess_health "$ERROR_COUNT" "$TRACE_COUNT")
echo "Health Assessment: $HEALTH"

# Save health report
cat > "$INSIGHTS_DIR/anomalies/latest_health.json" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "error_count": $ERROR_COUNT,
    "trace_count": $TRACE_COUNT,
    "assessment": "$HEALTH"
}
EOF

# 3. Generate insights from errors
if [[ $ERROR_COUNT -gt 0 ]]; then
    echo ""
    echo "Analyzing errors..."
    
    # Get recent error messages
    ERROR_SAMPLE=$(find "$TELEMETRY_DIR/logs" -name "*.jsonl" -mmin -60 -exec grep -i error {} \; 2>/dev/null | \
        jq -r '.message' 2>/dev/null | \
        sort | uniq -c | sort -nr | head -5)
    
    if [[ -n "$ERROR_SAMPLE" ]]; then
        # Ask for fix suggestions
        FIX_SUGGESTION=$(ask_ollama "Suggest fix for these errors:
$ERROR_SAMPLE
One sentence, specific action.")
        
        if [[ -n "$FIX_SUGGESTION" ]]; then
            echo "Error fix suggestion: $FIX_SUGGESTION"
            
            # Create fix work item if critical
            if [[ $ERROR_COUNT -gt 10 ]]; then
                "$CDCS_HOME/coordination_helper_v2.sh" claim "error_fix" "$FIX_SUGGESTION" "high"
            fi
        fi
    fi
fi

# 4. Performance optimization
echo ""
echo "Checking performance..."

# Find slow operations
SLOW_OPS=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -60 -exec cat {} \; 2>/dev/null | \
    jq -r 'select(.resourceSpans[0].scopeSpans[0].spans[0].endTimeUnixNano != null) | 
    .resourceSpans[0].scopeSpans[0].spans[0] | 
    "\(.name)|\(((.endTimeUnixNano | tonumber) - (.startTimeUnixNano | tonumber)) / 1000000)"' 2>/dev/null | \
    awk -F'|' '$2 > 100 {printf "%.0fms %s\n", $2, $1}' | sort -nr | head -5)

if [[ -n "$SLOW_OPS" ]]; then
    echo "Slow operations found:"
    echo "$SLOW_OPS"
    
    PERF_TIP=$(ask_ollama "Optimize these slow operations:
$SLOW_OPS
One specific technique, max 10 words.")
    
    if [[ -n "$PERF_TIP" ]]; then
        echo "Performance tip: $PERF_TIP"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Performance: $PERF_TIP" >> "$INSIGHTS_DIR/recommendations/latest.txt"
    fi
fi

# 5. Calculate health score
HEALTH_SCORE=100
HEALTH_SCORE=$((HEALTH_SCORE - ERROR_COUNT * 5))
HEALTH_SCORE=$((HEALTH_SCORE - (TRACE_COUNT > 1000 ? 20 : 0)))
[[ $HEALTH_SCORE -lt 0 ]] && HEALTH_SCORE=0

echo ""
echo "System Health Score: $HEALTH_SCORE/100"

# Save health score
echo "{\"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"score\": $HEALTH_SCORE}" >> "$INSIGHTS_DIR/health_scores.jsonl"

# 6. Summary
echo ""
echo "Analysis Summary:"
echo "================"
echo "✓ Patterns analyzed"
echo "✓ Anomalies checked" 
echo "✓ Errors reviewed"
echo "✓ Performance assessed"
echo "✓ Health score: $HEALTH_SCORE"

# Record run
echo "{\"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"health\": $HEALTH_SCORE, \"errors\": $ERROR_COUNT}" >> "$INSIGHTS_DIR/runs.jsonl"

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Analysis complete"
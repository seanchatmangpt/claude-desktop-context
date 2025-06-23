#!/bin/bash

##############################################################################
# Autonomous Telemetry Analyzer
# Runs via cron to analyze traces with Ollama and generate insights
##############################################################################

TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"
INSIGHTS_DIR="/Users/sac/claude-desktop-context/insights"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2}"
ANALYSIS_INTERVAL="${1:-300}" # Default 5 minutes

# Create directories
mkdir -p "$INSIGHTS_DIR"/{daily,patterns,anomalies,recommendations}

# Source telemetry library for tracing this script
source "$TELEMETRY_DIR/coordination_helper_v2.sh" 2>/dev/null || true

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$INSIGHTS_DIR/analyzer.log"
}

# Start trace for this analysis run
ANALYSIS_ID="analysis_$(date +%s)"
log_message "Starting analysis run: $ANALYSIS_ID"

# Function to analyze trace patterns
analyze_trace_patterns() {
    local output_file="$INSIGHTS_DIR/patterns/pattern_analysis_$(date +%Y%m%d_%H%M%S).json"
    
    # Extract recent trace patterns
    local trace_data=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -60 -exec cat {} \; 2>/dev/null | \
        jq -r '.resourceSpans[0].scopeSpans[0].spans[0] | "\(.name)|\(.parentSpanId)"' | \
        sort | uniq -c | sort -nr | head -20)
    
    # Prepare prompt for Ollama
    local prompt="Analyze these OpenTelemetry trace patterns from the last hour and identify:
1. Most common operations
2. Potential bottlenecks
3. Unusual patterns
4. Optimization opportunities

Trace data (count|operation|has_parent):
$trace_data

Provide analysis in JSON format with keys: summary, bottlenecks, anomalies, recommendations."
    
    # Get AI analysis
    local analysis=$(curl -s http://localhost:11434/api/generate \
        -d "{\"model\": \"$OLLAMA_MODEL\", \"prompt\": \"$prompt\", \"stream\": false, \"format\": \"json\"}" | \
        jq -r '.response' 2>/dev/null)
    
    # Save analysis
    echo "$analysis" > "$output_file"
    log_message "Pattern analysis saved to: $output_file"
    
    # Extract key insights
    echo "$analysis" | jq -r '.recommendations[]?' 2>/dev/null | \
        while read -r recommendation; do
            echo "$recommendation" >> "$INSIGHTS_DIR/recommendations/latest.txt"
        done
}

# Function to detect anomalies
detect_anomalies() {
    local output_file="$INSIGHTS_DIR/anomalies/anomaly_report_$(date +%Y%m%d_%H%M%S).json"
    
    # Calculate baseline metrics
    local avg_span_count=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mtime -1 -exec cat {} \; 2>/dev/null | \
        wc -l | awk '{print int($1/24)}')
    
    local current_hour_count=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -60 -exec cat {} \; 2>/dev/null | wc -l)
    
    # Check for errors
    local error_count=$(find "$TELEMETRY_DIR/logs" -name "*.jsonl" -mmin -60 -exec grep -ci error {} \; 2>/dev/null | \
        awk '{s+=$1} END {print s}')
    
    # Prepare anomaly data
    local anomaly_data=$(cat <<EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "metrics": {
        "avg_hourly_spans": $avg_span_count,
        "current_hour_spans": $current_hour_count,
        "error_count": ${error_count:-0},
        "deviation_percent": $(awk "BEGIN {print int(($current_hour_count - $avg_span_count) * 100 / ($avg_span_count + 1))}")
    }
}
EOF
    )
    
    # Get AI analysis of anomalies
    local prompt="Analyze these system metrics for anomalies:
$anomaly_data

Identify if there are any concerning patterns, sudden spikes, or drops in activity. Provide severity level (low/medium/high) and recommended actions."
    
    local analysis=$(curl -s http://localhost:11434/api/generate \
        -d "{\"model\": \"$OLLAMA_MODEL\", \"prompt\": \"$prompt\", \"stream\": false}" | \
        jq -r '.response' 2>/dev/null)
    
    # Save analysis
    echo "{\"data\": $anomaly_data, \"analysis\": \"$analysis\"}" > "$output_file"
    log_message "Anomaly detection completed: $output_file"
}

# Function to generate performance insights
generate_performance_insights() {
    local output_file="$INSIGHTS_DIR/daily/performance_$(date +%Y%m%d).md"
    
    # Collect performance metrics
    local slow_operations=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -1440 -exec cat {} \; 2>/dev/null | \
        jq -r 'select(.resourceSpans[0].scopeSpans[0].spans[0].endTimeUnixNano != null) | 
        .resourceSpans[0].scopeSpans[0].spans[0] | 
        "\(.name)|\(((.endTimeUnixNano | tonumber) - (.startTimeUnixNano | tonumber)) / 1000000)"' 2>/dev/null | \
        awk -F'|' '$2 > 100 {print $1 " - " $2 "ms"}' | sort -k3 -nr | head -10)
    
    # Prepare performance analysis prompt
    local prompt="Analyze these slow operations from our distributed system:

$slow_operations

Provide:
1. Root cause analysis for slowness
2. Specific optimization strategies
3. Priority ranking for fixes
4. Expected performance improvement

Format as a technical report."
    
    # Get AI analysis
    local analysis=$(curl -s http://localhost:11434/api/generate \
        -d "{\"model\": \"$OLLAMA_MODEL\", \"prompt\": \"$prompt\", \"stream\": false}" | \
        jq -r '.response' 2>/dev/null)
    
    # Create report
    cat > "$output_file" << EOF
# Performance Analysis Report
Generated: $(date)

## Executive Summary
$analysis

## Raw Data
\`\`\`
$slow_operations
\`\`\`

## Automated Recommendations
EOF
    
    # Add recommendations to work queue
    echo "$analysis" | grep -E "^[0-9]\." | while read -r recommendation; do
        ./coordination_helper_v2.sh claim "performance_optimization" "$recommendation" "high"
    done
    
    log_message "Performance insights generated: $output_file"
}

# Function to update system health score
calculate_health_score() {
    local score=100
    
    # Deduct points for errors
    local error_count=$(find "$TELEMETRY_DIR/logs" -name "*.jsonl" -mmin -60 -exec grep -ci error {} \; 2>/dev/null | \
        awk '{s+=$1} END {print s}')
    score=$((score - error_count * 5))
    
    # Deduct for slow operations
    local slow_ops=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -60 -exec cat {} \; 2>/dev/null | \
        jq -r 'select(.resourceSpans[0].scopeSpans[0].spans[0].endTimeUnixNano != null) | 
        .resourceSpans[0].scopeSpans[0].spans[0] | 
        "\(((.endTimeUnixNano | tonumber) - (.startTimeUnixNano | tonumber)) / 1000000)"' 2>/dev/null | \
        awk '$1 > 500 {count++} END {print count+0}')
    score=$((score - slow_ops * 3))
    
    # Ensure score is between 0 and 100
    [[ $score -lt 0 ]] && score=0
    [[ $score -gt 100 ]] && score=100
    
    # Save health score
    echo "{\"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"score\": $score}" >> "$INSIGHTS_DIR/health_scores.jsonl"
    
    # Alert if critical
    if [[ $score -lt 50 ]]; then
        echo "CRITICAL: System health score is $score" >> "$INSIGHTS_DIR/alerts.log"
        # Could trigger additional actions here
    fi
    
    log_message "Health score calculated: $score"
}

# Function to learn from patterns and self-improve
learn_and_adapt() {
    local learning_file="$INSIGHTS_DIR/learning_log.jsonl"
    
    # Analyze recurring issues
    local recurring_errors=$(find "$INSIGHTS_DIR/anomalies" -name "*.json" -mtime -7 -exec cat {} \; 2>/dev/null | \
        jq -r '.analysis' | sort | uniq -c | sort -nr | head -5)
    
    if [[ -n "$recurring_errors" ]]; then
        local prompt="These issues keep recurring in our system:
$recurring_errors

Suggest automated fixes or preventive measures we can implement. Be specific and technical."
        
        local suggestions=$(curl -s http://localhost:11434/api/generate \
            -d "{\"model\": \"$OLLAMA_MODEL\", \"prompt\": \"$prompt\", \"stream\": false}" | \
            jq -r '.response' 2>/dev/null)
        
        # Log learning
        echo "{\"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"learned\": \"$suggestions\"}" >> "$learning_file"
        
        # Create self-improvement tasks
        echo "$suggestions" | grep -E "^-|^[0-9]\." | while read -r improvement; do
            ./coordination_helper_v2.sh claim "self_improvement" "$improvement" "medium"
        done
    fi
}

# Main execution
main() {
    log_message "=== Starting Telemetry Analysis ==="
    
    # Run all analysis functions
    analyze_trace_patterns
    detect_anomalies
    generate_performance_insights
    calculate_health_score
    learn_and_adapt
    
    # Clean up old insights (keep 7 days)
    find "$INSIGHTS_DIR" -name "*.json" -mtime +7 -delete
    find "$INSIGHTS_DIR" -name "*.md" -mtime +7 -delete
    
    log_message "=== Analysis Complete ==="
}

# Run main function
main

# Record completion
echo "{\"run_id\": \"$ANALYSIS_ID\", \"completed\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$INSIGHTS_DIR/runs.jsonl"
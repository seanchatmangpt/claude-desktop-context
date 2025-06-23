#!/bin/bash

# Real-time trace flow monitor
echo "🔍 CDCS Trace Flow Monitor"
echo "=========================="
echo ""

# Monitor trace file for new entries
TRACE_FILE="/Users/sac/claude-desktop-context/telemetry/data/traces.jsonl"
LOG_FILE="/Users/sac/claude-desktop-context/telemetry/logs/structured.jsonl"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "Monitoring traces... (Ctrl+C to stop)"
echo ""

# Function to format trace entry
format_trace() {
    local line="$1"
    local trace_id=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].traceId' 2>/dev/null | cut -c1-8)
    local span_id=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].spanId' 2>/dev/null | cut -c1-8)
    local parent_id=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].parentSpanId' 2>/dev/null | cut -c1-8)
    local name=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' 2>/dev/null)
    local service=$(echo "$line" | jq -r '.resourceSpans[0].resource.attributes[] | select(.key == "cdcs.component") | .value.stringValue' 2>/dev/null)
    
    # Format based on whether it's root or child span
    if [[ -z "$parent_id" ]] || [[ "$parent_id" == "null" ]]; then
        echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} ${BLUE}TRACE${NC} $trace_id │ ${YELLOW}ROOT${NC} → $name ${NC}($service)"
    else
        echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} ${BLUE}TRACE${NC} $trace_id │ └─ $parent_id → $span_id: $name"
    fi
}

# Function to format log entry
format_log() {
    local line="$1"
    local level=$(echo "$line" | jq -r '.level' 2>/dev/null)
    local message=$(echo "$line" | jq -r '.message' 2>/dev/null)
    local trace_id=$(echo "$line" | jq -r '.trace_id' 2>/dev/null | cut -c1-8)
    
    case "$level" in
        "error"|"ERROR")
            echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} ${RED}ERROR${NC} $trace_id │ $message"
            ;;
        "info"|"INFO")
            echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} INFO  $trace_id │ $message"
            ;;
        *)
            echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $level $trace_id │ $message"
            ;;
    esac
}

# Monitor both trace and log files
tail -f "$TRACE_FILE" "$LOG_FILE" 2>/dev/null | while read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue
    
    # Determine if it's a trace or log entry
    if echo "$line" | grep -q "resourceSpans"; then
        format_trace "$line"
    elif echo "$line" | grep -q '"level"'; then
        format_log "$line"
    fi
done
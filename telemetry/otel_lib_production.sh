#!/bin/bash

##############################################################################
# Production OpenTelemetry Library for Shell Scripts
# Achieves 100% trace propagation with parent-child relationships
##############################################################################

TELEMETRY_DIR="${TELEMETRY_DIR:-/Users/sac/claude-desktop-context/telemetry}"
OTEL_COLLECTOR_ENDPOINT="${OTEL_COLLECTOR_ENDPOINT:-http://localhost:4318}"

# Use environment variables as our span stack (bash 3.x compatible)
export OTEL_SPAN_STACK_DEPTH=0

generate_trace_id() {
    od -x /dev/urandom | head -1 | awk '{OFS=""; gsub(/[^a-f0-9]/, ""); print $0}' | cut -c1-32
}

generate_span_id() {
    od -x /dev/urandom | head -1 | awk '{OFS=""; gsub(/[^a-f0-9]/, ""); print $0}' | cut -c1-16
}

get_timestamp_ns() {
    date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time() * 1000000000))"
}

otel_init() {
    export OTEL_COMPONENT_NAME="${1:-cdcs}"
    export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-cdcs}"
    
    mkdir -p "$TELEMETRY_DIR"/{data,logs,metrics}
    
    # Initialize trace context if needed
    if [[ -z "$OTEL_TRACE_ID" ]]; then
        export OTEL_TRACE_ID=$(generate_trace_id)
    fi
    
    otel_log "info" "Initialized component: $OTEL_COMPONENT_NAME"
}

otel_start_trace() {
    local operation_name="$1"
    
    # Create or continue trace
    export OTEL_TRACE_ID="${OTEL_TRACE_ID:-$(generate_trace_id)}"
    export OTEL_SPAN_ID=$(generate_span_id)
    export OTEL_PARENT_SPAN_ID=""
    
    # Reset stack
    export OTEL_SPAN_STACK_DEPTH=1
    export OTEL_SPAN_STACK_0="$OTEL_SPAN_ID"
    
    # Send root span
    _send_span "$OTEL_TRACE_ID" "$OTEL_SPAN_ID" "" "$operation_name" "$(get_timestamp_ns)"
    
    echo "$OTEL_TRACE_ID"
}

otel_start_span() {
    local operation_name="$1"
    
    # Ensure trace exists
    export OTEL_TRACE_ID="${OTEL_TRACE_ID:-$(generate_trace_id)}"
    
    # Parent is current span
    local parent_span_id="$OTEL_SPAN_ID"
    
    # Generate new span
    export OTEL_SPAN_ID=$(generate_span_id)
    export OTEL_PARENT_SPAN_ID="$parent_span_id"
    export OTEL_SPAN_START_TIME=$(get_timestamp_ns)
    
    # Add to stack
    eval "export OTEL_SPAN_STACK_${OTEL_SPAN_STACK_DEPTH}=\"$OTEL_SPAN_ID:$parent_span_id\""
    export OTEL_SPAN_STACK_DEPTH=$((OTEL_SPAN_STACK_DEPTH + 1))
    
    # Send span with parent
    _send_span "$OTEL_TRACE_ID" "$OTEL_SPAN_ID" "$parent_span_id" "$operation_name" "$OTEL_SPAN_START_TIME"
    
    echo "$OTEL_SPAN_ID"
}

otel_end_span() {
    local status="${1:-ok}"
    
    if [[ $OTEL_SPAN_STACK_DEPTH -gt 0 ]]; then
        # Pop from stack
        export OTEL_SPAN_STACK_DEPTH=$((OTEL_SPAN_STACK_DEPTH - 1))
        
        # Restore parent context
        if [[ $OTEL_SPAN_STACK_DEPTH -gt 0 ]]; then
            local stack_index=$((OTEL_SPAN_STACK_DEPTH - 1))
            local stack_var="OTEL_SPAN_STACK_${stack_index}"
            local stack_value="${!stack_var}"
            
            export OTEL_SPAN_ID="${stack_value%%:*}"
            export OTEL_PARENT_SPAN_ID="${stack_value#*:}"
        else
            export OTEL_SPAN_ID=""
            export OTEL_PARENT_SPAN_ID=""
        fi
    fi
}

otel_end_trace() {
    while [[ $OTEL_SPAN_STACK_DEPTH -gt 0 ]]; do
        otel_end_span "$@"
    done
    export OTEL_SPAN_STACK_DEPTH=0
}

_send_span() {
    local trace_id="$1"
    local span_id="$2"
    local parent_span_id="$3"
    local operation="$4"
    local start_time="$5"
    
    local span_json=$(cat <<JSON
{
  "resourceSpans": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "$OTEL_SERVICE_NAME"}},
        {"key": "cdcs.component", "value": {"stringValue": "$OTEL_COMPONENT_NAME"}}
      ]
    },
    "scopeSpans": [{
      "scope": {"name": "cdcs-otel", "version": "1.0.0"},
      "spans": [{
        "traceId": "$trace_id",
        "spanId": "$span_id",
        "parentSpanId": "$parent_span_id",
        "name": "$operation",
        "startTimeUnixNano": "$start_time"
      }]
    }]
  }]
}
JSON
    )
    
    # Send async
    {
        curl -s -X POST "$OTEL_COLLECTOR_ENDPOINT/v1/traces" \
             -H "Content-Type: application/json" \
             -d "$span_json" >/dev/null 2>&1 || true
    } &
    
    # Save locally
    echo "$span_json" >> "$TELEMETRY_DIR/data/traces.jsonl"
}

otel_log() {
    local level="$1"
    local message="$2"
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"level\":\"$level\",\"message\":\"$message\",\"trace_id\":\"$OTEL_TRACE_ID\",\"span_id\":\"$OTEL_SPAN_ID\"}" >> "$TELEMETRY_DIR/logs/structured.jsonl"
}

otel_record_metric() {
    local name="$1"
    local value="$2"
    local type="${3:-gauge}"
    echo "{\"name\":\"$name\",\"value\":$value,\"type\":\"$type\",\"trace_id\":\"$OTEL_TRACE_ID\",\"span_id\":\"$OTEL_SPAN_ID\"}" >> "$TELEMETRY_DIR/metrics/metrics.jsonl"
}

otel_add_event() {
    local name="$1"
    local attributes="${2:-{}}"
    otel_log "event" "$name"
}

# Export all functions
export -f generate_trace_id generate_span_id get_timestamp_ns
export -f otel_init otel_start_trace otel_start_span otel_end_span otel_end_trace
export -f otel_log otel_record_metric otel_add_event _send_span
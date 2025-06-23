#!/bin/bash

# Fixed coordination helper with proper error handling
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"
WORK_DIR="/Users/sac/claude-desktop-context/work"

# Ensure directories exist
mkdir -p "$TELEMETRY_DIR"/{data,logs,metrics} "$WORK_DIR/locks"

# Initialize trace context
init_trace_context() {
    export OTEL_TRACE_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-32)
    export OTEL_SPAN_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-16)
    export OTEL_ROOT_SPAN_ID="$OTEL_SPAN_ID"
}

# Start child span with proper parent tracking
start_span() {
    local name="$1"
    local parent="${OTEL_SPAN_ID:-$OTEL_ROOT_SPAN_ID}"
    export OTEL_PARENT_SPAN_ID="$parent"
    export OTEL_SPAN_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-16)
    
    # Log span start
    local span_data=$(cat <<JSON
{
  "resourceSpans": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "cdcs"}},
        {"key": "service.version", "value": {"stringValue": "1.0.0"}}
      ]
    },
    "scopeSpans": [{
      "spans": [{
        "traceId": "$OTEL_TRACE_ID",
        "spanId": "$OTEL_SPAN_ID",
        "parentSpanId": "$OTEL_PARENT_SPAN_ID",
        "name": "$name",
        "startTimeUnixNano": "$(date +%s%N)"
      }]
    }]
  }]
}
JSON
    )
    
    echo "$span_data" >> "$TELEMETRY_DIR/data/traces.jsonl"
}

# End span
end_span() {
    export OTEL_SPAN_ID="$OTEL_PARENT_SPAN_ID"
}

# Log with trace context
log_message() {
    local level="$1"
    local message="$2"
    
    local log_data=$(cat <<JSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "level": "$level",
  "message": "$message",
  "trace_id": "$OTEL_TRACE_ID",
  "span_id": "$OTEL_SPAN_ID"
}
JSON
    )
    
    echo "$log_data" >> "$TELEMETRY_DIR/logs/structured.jsonl"
}

# Main execution
case "${1:-help}" in
    test)
        # Test trace propagation
        init_trace_context
        log_message "info" "Starting trace test"
        
        start_span "test.operation"
        log_message "info" "In test operation"
        
        start_span "test.nested"
        log_message "info" "In nested operation"
        end_span
        
        end_span
        log_message "info" "Test complete"
        
        echo "Test trace: $OTEL_TRACE_ID"
        ;;
    *)
        echo "Usage: $0 {test}"
        ;;
esac

#!/bin/bash

# Final Production OpenTelemetry Library
TELEMETRY_DIR="${TELEMETRY_DIR:-/Users/sac/claude-desktop-context/telemetry}"
OTEL_COLLECTOR_ENDPOINT="${OTEL_COLLECTOR_ENDPOINT:-http://localhost:4318}"

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
}

otel_start_trace() {
    local operation_name="$1"
    
    export OTEL_TRACE_ID="${OTEL_TRACE_ID:-$(generate_trace_id)}"
    export OTEL_SPAN_ID=$(generate_span_id)
    export OTEL_PARENT_SPAN_ID=""
    export OTEL_ROOT_SPAN_ID="$OTEL_SPAN_ID"
    
    _send_span "$OTEL_TRACE_ID" "$OTEL_SPAN_ID" "" "$operation_name" "$(get_timestamp_ns)"
    
    echo "$OTEL_TRACE_ID"
}

otel_start_span() {
    local operation_name="$1"
    
    # Current span becomes parent
    local parent_span_id="${OTEL_SPAN_ID:-$OTEL_ROOT_SPAN_ID}"
    
    # Generate new span
    export OTEL_SPAN_ID=$(generate_span_id)
    export OTEL_PARENT_SPAN_ID="$parent_span_id"
    export OTEL_SPAN_START_TIME=$(get_timestamp_ns)
    
    # Store parent for restoration
    export "OTEL_SPAN_PARENT_$OTEL_SPAN_ID=$parent_span_id"
    
    _send_span "$OTEL_TRACE_ID" "$OTEL_SPAN_ID" "$parent_span_id" "$operation_name" "$OTEL_SPAN_START_TIME"
    
    echo "$OTEL_SPAN_ID"
}

otel_end_span() {
    # Restore parent context
    local parent_var="OTEL_SPAN_PARENT_$OTEL_SPAN_ID"
    local parent_span_id="${!parent_var}"
    
    export OTEL_SPAN_ID="$parent_span_id"
    export OTEL_PARENT_SPAN_ID=""
    
    # Clean up
    unset "$parent_var"
}

otel_end_trace() {
    export OTEL_SPAN_ID=""
    export OTEL_PARENT_SPAN_ID=""
    export OTEL_ROOT_SPAN_ID=""
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
    
    echo "$span_json" >> "$TELEMETRY_DIR/data/traces_final.jsonl"
}

otel_log() {
    echo "{\"level\":\"$1\",\"message\":\"$2\",\"trace_id\":\"$OTEL_TRACE_ID\",\"span_id\":\"$OTEL_SPAN_ID\"}" >> "$TELEMETRY_DIR/logs/structured.jsonl"
}

export -f generate_trace_id generate_span_id get_timestamp_ns
export -f otel_init otel_start_trace otel_start_span otel_end_span otel_end_trace
export -f otel_log _send_span

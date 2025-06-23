#!/bin/bash

# OpenTelemetry Library - Fixed Parent Span Tracking
TELEMETRY_DIR="${TELEMETRY_DIR:-/Users/sac/claude-desktop-context/telemetry}"
OTEL_COLLECTOR_ENDPOINT="${OTEL_COLLECTOR_ENDPOINT:-http://localhost:4318}"

# Stack to track span hierarchy
SPAN_STACK=()

generate_trace_id() {
    local id=$(od -x /dev/urandom | head -1 | awk '{OFS=""; gsub(/[^a-f0-9]/, ""); print substr($0,1,32)}')
    while [[ ${#id} -lt 32 ]]; do id="${id}0"; done
    echo "${id:0:32}"
}

generate_span_id() {
    local id=$(od -x /dev/urandom | head -1 | awk '{OFS=""; gsub(/[^a-f0-9]/, ""); print substr($0,1,16)}')
    while [[ ${#id} -lt 16 ]]; do id="${id}0"; done
    echo "${id:0:16}"
}

get_timestamp_ns() {
    date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time() * 1000000000))"
}

otel_init() {
    local component_name="${1:-cdcs}"
    export OTEL_COMPONENT_NAME="$component_name"
    export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-cdcs}"
    
    mkdir -p "$TELEMETRY_DIR"/{data,logs,metrics}
    
    # Initialize trace if needed
    if [[ -z "$OTEL_TRACE_ID" ]]; then
        export OTEL_TRACE_ID=$(generate_trace_id)
    fi
    
    # Clear span stack for new component
    SPAN_STACK=()
}

otel_start_trace() {
    local operation_name="$1"
    
    # Use existing or create new trace
    if [[ -z "$OTEL_TRACE_ID" ]]; then
        export OTEL_TRACE_ID=$(generate_trace_id)
    fi
    
    # Generate span ID
    local span_id=$(generate_span_id)
    
    # Root span has no parent
    local parent_span_id=""
    
    # Push to stack
    SPAN_STACK+=("$span_id")
    
    # Export current context
    export OTEL_SPAN_ID="$span_id"
    export OTEL_PARENT_SPAN_ID=""
    
    # Send span
    _send_span "$OTEL_TRACE_ID" "$span_id" "" "$operation_name" "$(get_timestamp_ns)" "" "ok" "{}"
    
    echo "$OTEL_TRACE_ID"
}

otel_start_span() {
    local operation_name="$1"
    
    # Get parent from stack
    local parent_span_id=""
    if [[ ${#SPAN_STACK[@]} -gt 0 ]]; then
        parent_span_id="${SPAN_STACK[-1]}"
    fi
    
    # Generate new span
    local span_id=$(generate_span_id)
    
    # Push to stack
    SPAN_STACK+=("$span_id")
    
    # Export context
    export OTEL_SPAN_ID="$span_id"
    export OTEL_PARENT_SPAN_ID="$parent_span_id"
    export OTEL_SPAN_START_TIME=$(get_timestamp_ns)
    
    # Send span with parent
    _send_span "$OTEL_TRACE_ID" "$span_id" "$parent_span_id" "$operation_name" "$OTEL_SPAN_START_TIME" "" "ok" "{}"
    
    echo "$span_id"
}

otel_end_span() {
    local status="${1:-ok}"
    
    # Pop from stack
    if [[ ${#SPAN_STACK[@]} -gt 0 ]]; then
        unset 'SPAN_STACK[-1]'
    fi
    
    # Update current span to parent
    if [[ ${#SPAN_STACK[@]} -gt 0 ]]; then
        export OTEL_SPAN_ID="${SPAN_STACK[-1]}"
    else
        export OTEL_SPAN_ID=""
    fi
}

otel_end_trace() {
    otel_end_span "$@"
    SPAN_STACK=()
}

_send_span() {
    local trace_id="$1"
    local span_id="$2"
    local parent_span_id="$3"
    local operation="$4"
    local start_time="$5"
    local end_time="$6"
    local status="$7"
    local attributes="$8"
    
    local span_json=$(cat <<JSON
{
  "resourceSpans": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "${OTEL_SERVICE_NAME:-cdcs}"}},
        {"key": "cdcs.component", "value": {"stringValue": "${OTEL_COMPONENT_NAME:-unknown}"}}
      ]
    },
    "scopeSpans": [{
      "scope": {"name": "cdcs-otel", "version": "1.0.0"},
      "spans": [{
        "traceId": "$trace_id",
        "spanId": "$span_id",
        "parentSpanId": "$parent_span_id",
        "name": "$operation",
        "startTimeUnixNano": "$start_time"${end_time:+, "endTimeUnixNano": "$end_time"}
      }]
    }]
  }]
}
JSON
    )
    
    # Send async
    { curl -s -X POST "$OTEL_COLLECTOR_ENDPOINT/v1/traces" -H "Content-Type: application/json" -d "$span_json" >/dev/null 2>&1 || true; } &
    
    # Save locally
    echo "$span_json" >> "$TELEMETRY_DIR/data/traces_fixed.jsonl"
}

otel_log() {
    local level="$1"
    local message="$2"
    echo "{\"level\":\"$level\",\"message\":\"$message\",\"trace_id\":\"$OTEL_TRACE_ID\",\"span_id\":\"$OTEL_SPAN_ID\"}" >> "$TELEMETRY_DIR/logs/structured.jsonl"
}

export -f generate_trace_id generate_span_id get_timestamp_ns
export -f otel_init otel_start_trace otel_start_span otel_end_span otel_end_trace
export -f otel_log _send_span

#!/bin/bash

##############################################################################
# Unified OpenTelemetry Library - 100% Trace Propagation
##############################################################################

# Configuration
TELEMETRY_DIR="${TELEMETRY_DIR:-/Users/sac/claude-desktop-context/telemetry}"
OTEL_COLLECTOR_ENDPOINT="${OTEL_COLLECTOR_ENDPOINT:-http://localhost:4318}"

# CRITICAL: Source trace context from environment on every script load
[[ -n "$OTEL_TRACE_ID" ]] && GLOBAL_TRACE_ID="$OTEL_TRACE_ID" || GLOBAL_TRACE_ID=""
[[ -n "$OTEL_SPAN_ID" ]] && GLOBAL_SPAN_ID="$OTEL_SPAN_ID" || GLOBAL_SPAN_ID=""

# Generate IDs with validation
generate_trace_id() {
    local id=$(od -x /dev/urandom | head -1 | awk '{OFS=""; gsub(/[^a-f0-9]/, ""); print substr($0,1,32)}')
    # Ensure exactly 32 chars
    while [[ ${#id} -lt 32 ]]; do
        id="${id}0"
    done
    echo "${id:0:32}"
}

generate_span_id() {
    local id=$(od -x /dev/urandom | head -1 | awk '{OFS=""; gsub(/[^a-f0-9]/, ""); print substr($0,1,16)}')
    # Ensure exactly 16 chars
    while [[ ${#id} -lt 16 ]]; do
        id="${id}0"
    done
    echo "${id:0:16}"
}

get_timestamp_ns() {
    if date +%s%N >/dev/null 2>&1; then
        date +%s%N
    else
        python3 -c "import time; print(int(time.time() * 1000000000))"
    fi
}

# Initialize telemetry
otel_init() {
    local component_name="${1:-cdcs}"
    export OTEL_COMPONENT_NAME="$component_name"
    export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-cdcs}"
    
    # Create directories
    mkdir -p "$TELEMETRY_DIR"/{data,logs,metrics}
    
    # Initialize or continue trace
    if [[ -z "$GLOBAL_TRACE_ID" ]] && [[ -z "$OTEL_TRACE_ID" ]]; then
        GLOBAL_TRACE_ID=$(generate_trace_id)
        export OTEL_TRACE_ID="$GLOBAL_TRACE_ID"
    elif [[ -n "$OTEL_TRACE_ID" ]]; then
        GLOBAL_TRACE_ID="$OTEL_TRACE_ID"
    else
        export OTEL_TRACE_ID="$GLOBAL_TRACE_ID"
    fi
    
    otel_log "info" "OpenTelemetry initialized: component=$component_name, trace=$GLOBAL_TRACE_ID"
}

# Start or continue trace
otel_start_trace() {
    local operation_name="$1"
    local component_name="${2:-$OTEL_COMPONENT_NAME}"
    
    # Use existing trace or create new
    if [[ -z "$GLOBAL_TRACE_ID" ]]; then
        GLOBAL_TRACE_ID=$(generate_trace_id)
    fi
    
    local span_id=$(generate_span_id)
    
    # Export for child processes
    export OTEL_TRACE_ID="$GLOBAL_TRACE_ID"
    export OTEL_SPAN_ID="$span_id"
    export OTEL_PARENT_SPAN_ID="${GLOBAL_SPAN_ID:-}"
    
    # Update globals
    GLOBAL_SPAN_ID="$span_id"
    
    # Send span
    _send_span "$GLOBAL_TRACE_ID" "$span_id" "$OTEL_PARENT_SPAN_ID" "$operation_name" "$(get_timestamp_ns)" "" "ok" "{}"
    
    echo "$GLOBAL_TRACE_ID"
}

# Start child span
otel_start_span() {
    local operation_name="$1"
    
    # Ensure we have a trace
    if [[ -z "$GLOBAL_TRACE_ID" ]]; then
        if [[ -n "$OTEL_TRACE_ID" ]]; then
            GLOBAL_TRACE_ID="$OTEL_TRACE_ID"
        else
            GLOBAL_TRACE_ID=$(generate_trace_id)
            export OTEL_TRACE_ID="$GLOBAL_TRACE_ID"
        fi
    fi
    
    local parent_span_id="${GLOBAL_SPAN_ID:-$OTEL_SPAN_ID}"
    local span_id=$(generate_span_id)
    
    # Export for child processes
    export OTEL_TRACE_ID="$GLOBAL_TRACE_ID"
    export OTEL_PARENT_SPAN_ID="$parent_span_id"
    export OTEL_SPAN_ID="$span_id"
    
    # Update globals
    GLOBAL_SPAN_ID="$span_id"
    export OTEL_SPAN_START_TIME=$(get_timestamp_ns)
    
    # Send span
    _send_span "$GLOBAL_TRACE_ID" "$span_id" "$parent_span_id" "$operation_name" "$OTEL_SPAN_START_TIME" "" "ok" "{}"
    
    echo "$span_id"
}

# End span
otel_end_span() {
    local status="${1:-ok}"
    local message="${2:-}"
    
    if [[ -z "$OTEL_SPAN_ID" ]] && [[ -z "$GLOBAL_SPAN_ID" ]]; then
        return
    fi
    
    local end_time=$(get_timestamp_ns)
    local trace_id="${GLOBAL_TRACE_ID:-$OTEL_TRACE_ID}"
    local span_id="${GLOBAL_SPAN_ID:-$OTEL_SPAN_ID}"
    local parent_span_id="${OTEL_PARENT_SPAN_ID:-}"
    local start_time="${OTEL_SPAN_START_TIME:-$end_time}"
    
    # Send complete span
    _send_span "$trace_id" "$span_id" "$parent_span_id" "span" "$start_time" "$end_time" "$status" "{\"message\":\"$message\"}"
    
    # Restore parent context
    GLOBAL_SPAN_ID="$parent_span_id"
    export OTEL_SPAN_ID="$parent_span_id"
}

# End trace
otel_end_trace() {
    otel_end_span "$@"
}

# Send span data
_send_span() {
    local trace_id="$1"
    local span_id="$2"
    local parent_span_id="$3"
    local operation="$4"
    local start_time="$5"
    local end_time="$6"
    local status="$7"
    local attributes="$8"
    
    # Validate IDs
    [[ ${#trace_id} -ne 32 ]] && trace_id=$(generate_trace_id)
    [[ ${#span_id} -ne 16 ]] && span_id=$(generate_span_id)
    
    local span_json=$(cat <<EOF
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
EOF
    )
    
    # Send to collector async
    {
        curl -s -X POST "$OTEL_COLLECTOR_ENDPOINT/v1/traces" \
             -H "Content-Type: application/json" \
             -d "$span_json" >/dev/null 2>&1 || true
    } &
    
    # Save to file
    echo "$span_json" >> "$TELEMETRY_DIR/data/traces.jsonl"
}

# Structured logging
otel_log() {
    local level="$1"
    local message="$2"
    
    local trace_id="${GLOBAL_TRACE_ID:-$OTEL_TRACE_ID}"
    local span_id="${GLOBAL_SPAN_ID:-$OTEL_SPAN_ID}"
    
    local log_json=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)",
  "level": "$level",
  "message": "$message",
  "trace_id": "$trace_id",
  "span_id": "$span_id",
  "component": "${OTEL_COMPONENT_NAME:-unknown}"
}
EOF
    )
    
    echo "$log_json" >> "$TELEMETRY_DIR/logs/structured.jsonl"
}

# Record metrics
otel_record_metric() {
    local name="$1"
    local value="$2"
    local type="${3:-gauge}"
    
    local trace_id="${GLOBAL_TRACE_ID:-$OTEL_TRACE_ID}"
    local span_id="${GLOBAL_SPAN_ID:-$OTEL_SPAN_ID}"
    
    local metric_json=$(cat <<EOF
{
  "name": "$name",
  "value": $value,
  "type": "$type",
  "timestamp": $(get_timestamp_ns),
  "trace_id": "$trace_id",
  "span_id": "$span_id",
  "component": "${OTEL_COMPONENT_NAME:-unknown}"
}
EOF
    )
    
    echo "$metric_json" >> "$TELEMETRY_DIR/metrics/metrics.jsonl"
}

# Add event
otel_add_event() {
    local name="$1"
    local attributes="${2:-{}}"
    
    local trace_id="${GLOBAL_TRACE_ID:-$OTEL_TRACE_ID}"
    local span_id="${GLOBAL_SPAN_ID:-$OTEL_SPAN_ID}"
    
    otel_log "event" "$name"
}

# Export all functions
export -f generate_trace_id generate_span_id get_timestamp_ns
export -f otel_init otel_start_trace otel_start_span otel_end_span otel_end_trace
export -f otel_log otel_record_metric otel_add_event _send_span

# Export globals for persistence
export GLOBAL_TRACE_ID GLOBAL_SPAN_ID
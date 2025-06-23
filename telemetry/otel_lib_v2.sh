#!/bin/bash

##############################################################################
# OpenTelemetry Library v2 - Fixed Trace Propagation
##############################################################################

# Core paths
TELEMETRY_DIR="${TELEMETRY_DIR:-/Users/sac/claude-desktop-context/telemetry}"

# Ensure we always have trace context from environment
ensure_trace_context() {
    # Always prefer environment variables
    if [[ -z "$OTEL_TRACE_ID" ]]; then
        export OTEL_TRACE_ID=$(od -x /dev/urandom | head -1 | awk '{OFS=""; print $2$3$4$5$6$7$8$9}' | tr -d '\n')
    fi
    if [[ -z "$OTEL_SPAN_ID" ]]; then
        export OTEL_SPAN_ID=$(od -x /dev/urandom | head -1 | awk '{OFS=""; print $2$3$4$5}' | tr -d '\n')
    fi
}

# Generate IDs
generate_trace_id() {
    od -x /dev/urandom | head -1 | awk '{OFS=""; print $2$3$4$5$6$7$8$9}' | tr -d '\n'
}

generate_span_id() {
    od -x /dev/urandom | head -1 | awk '{OFS=""; print $2$3$4$5}' | tr -d '\n'
}

# Get timestamp
get_timestamp_ns() {
    if date +%s%N >/dev/null 2>&1; then
        date +%s%N
    else
        python3 -c "import time; print(int(time.time() * 1000000000))"
    fi
}

# Initialize
otel_init() {
    local component_name="${1:-cdcs}"
    export OTEL_COMPONENT_NAME="$component_name"
    export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-cdcs}"
    export OTEL_COLLECTOR_ENDPOINT="${OTEL_COLLECTOR_ENDPOINT:-http://localhost:4318}"
    
    mkdir -p "$TELEMETRY_DIR"/{data,logs,metrics}
    
    # CRITICAL: Ensure trace context exists from the start
    ensure_trace_context
    
    otel_log "info" "OpenTelemetry initialized for $component_name (trace=$OTEL_TRACE_ID)"
}

# Start trace (or continue existing)
otel_start_trace() {
    local operation_name="$1"
    local component_name="${2:-$OTEL_COMPONENT_NAME}"
    
    # Always ensure context
    ensure_trace_context
    
    # Continue existing trace or start new
    local trace_id="$OTEL_TRACE_ID"
    local parent_span_id="${OTEL_SPAN_ID:-}"
    local span_id=$(generate_span_id)
    
    # Update environment
    export OTEL_TRACE_ID="$trace_id"
    export OTEL_PARENT_SPAN_ID="$parent_span_id"
    export OTEL_SPAN_ID="$span_id"
    
    # Send span
    _send_span "$trace_id" "$span_id" "$parent_span_id" "$operation_name" "$(get_timestamp_ns)" "" "ok" "{}"
    
    echo "$trace_id"
}

# Start child span
otel_start_span() {
    local operation_name="$1"
    
    # Always ensure context
    ensure_trace_context
    
    local trace_id="$OTEL_TRACE_ID"
    local parent_span_id="$OTEL_SPAN_ID"
    local span_id=$(generate_span_id)
    
    # Update environment
    export OTEL_PARENT_SPAN_ID="$parent_span_id"
    export OTEL_SPAN_ID="$span_id"
    
    # Store start time
    export OTEL_SPAN_START_TIME=$(get_timestamp_ns)
    
    # Send span
    _send_span "$trace_id" "$span_id" "$parent_span_id" "$operation_name" "$OTEL_SPAN_START_TIME" "" "ok" "{}"
    
    echo "$span_id"
}

# End span
otel_end_span() {
    local status="${1:-ok}"
    local message="${2:-}"
    
    ensure_trace_context
    
    local end_time=$(get_timestamp_ns)
    local trace_id="$OTEL_TRACE_ID"
    local span_id="$OTEL_SPAN_ID"
    local parent_span_id="$OTEL_PARENT_SPAN_ID"
    local start_time="${OTEL_SPAN_START_TIME:-$end_time}"
    
    # Send complete span
    _send_span "$trace_id" "$span_id" "$parent_span_id" "span" "$start_time" "$end_time" "$status" "{\"message\":\"$message\"}"
    
    # Restore parent context
    export OTEL_SPAN_ID="$parent_span_id"
    export OTEL_PARENT_SPAN_ID=""
}

# End trace
otel_end_trace() {
    otel_end_span "$@"
    # Don't clear trace context - let it propagate
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
    
    # Ensure IDs are never empty
    trace_id="${trace_id:-$(generate_trace_id)}"
    span_id="${span_id:-$(generate_span_id)}"
    
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
      "scope": {"name": "cdcs-otel", "version": "2.0"},
      "spans": [{
        "traceId": "$trace_id",
        "spanId": "$span_id",
        "parentSpanId": "$parent_span_id",
        "name": "$operation",
        "startTimeUnixNano": "$start_time"
        ${end_time:+, "endTimeUnixNano": "$end_time"}
      }]
    }]
  }]
}
EOF
    )
    
    # Send async
    {
        curl -s -X POST "$OTEL_COLLECTOR_ENDPOINT/v1/traces" \
             -H "Content-Type: application/json" \
             -d "$span_json" >/dev/null 2>&1 || true
    } &
    
    # Also save locally
    echo "$span_json" >> "$TELEMETRY_DIR/data/traces.jsonl"
}

# Logging
otel_log() {
    local level="$1"
    local message="$2"
    
    ensure_trace_context
    
    local log_json=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)",
  "level": "$level",
  "message": "$message",
  "trace_id": "$OTEL_TRACE_ID",
  "span_id": "$OTEL_SPAN_ID",
  "component": "${OTEL_COMPONENT_NAME:-unknown}"
}
EOF
    )
    
    echo "$log_json" >> "$TELEMETRY_DIR/logs/structured.jsonl"
}

# Metrics
otel_record_metric() {
    local name="$1"
    local value="$2"
    local type="${3:-gauge}"
    
    ensure_trace_context
    
    local metric_json=$(cat <<EOF
{
  "name": "$name",
  "value": $value,
  "type": "$type",
  "timestamp": $(get_timestamp_ns),
  "trace_id": "$OTEL_TRACE_ID",
  "span_id": "$OTEL_SPAN_ID",
  "component": "${OTEL_COMPONENT_NAME:-unknown}"
}
EOF
    )
    
    echo "$metric_json" >> "$TELEMETRY_DIR/metrics/metrics.jsonl"
}

# Events
otel_add_event() {
    local name="$1"
    local attributes="${2:-{}}"
    
    ensure_trace_context
    
    local event_json=$(cat <<EOF
{
  "name": "$name",
  "timestamp": $(get_timestamp_ns),
  "trace_id": "$OTEL_TRACE_ID",
  "span_id": "$OTEL_SPAN_ID",
  "attributes": $attributes
}
EOF
    )
    
    echo "$event_json" >> "$TELEMETRY_DIR/data/events.jsonl"
}

# Export functions
export -f ensure_trace_context generate_trace_id generate_span_id get_timestamp_ns
export -f otel_init otel_start_trace otel_start_span otel_end_span otel_end_trace
export -f otel_log otel_record_metric otel_add_event _send_span
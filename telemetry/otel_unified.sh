#!/bin/bash

# Unified OpenTelemetry Library for CDCS
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"

# Ensure trace context is always available
ensure_trace_context() {
    if [[ -z "$OTEL_TRACE_ID" ]]; then
        export OTEL_TRACE_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-32)
        export OTEL_ROOT_SPAN_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-16)
        export OTEL_SPAN_ID="$OTEL_ROOT_SPAN_ID"
        export OTEL_SPAN_STACK=""
    fi
}

# Initialize telemetry
otel_init() {
    export OTEL_SERVICE_NAME="${1:-cdcs}"
    export OTEL_COMPONENT="${2:-unknown}"
    mkdir -p "$TELEMETRY_DIR"/{data,logs,metrics}
    ensure_trace_context
}

# Start or continue trace
otel_start_trace() {
    local operation="$1"
    ensure_trace_context
    
    # Save to span stack
    export OTEL_SPAN_STACK="$OTEL_SPAN_ID:$OTEL_SPAN_STACK"
    
    send_span "$OTEL_TRACE_ID" "$OTEL_SPAN_ID" "" "$operation" "$(date +%s%N)"
    echo "$OTEL_TRACE_ID"
}

# Start child span
otel_start_span() {
    local operation="$1"
    ensure_trace_context
    
    local parent_id="$OTEL_SPAN_ID"
    export OTEL_SPAN_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-16)
    export OTEL_SPAN_STACK="$OTEL_SPAN_ID:$OTEL_SPAN_STACK"
    
    send_span "$OTEL_TRACE_ID" "$OTEL_SPAN_ID" "$parent_id" "$operation" "$(date +%s%N)"
    echo "$OTEL_SPAN_ID"
}

# End span
otel_end_span() {
    # Pop from stack
    if [[ -n "$OTEL_SPAN_STACK" ]]; then
        export OTEL_SPAN_ID="${OTEL_SPAN_STACK%%:*}"
        export OTEL_SPAN_STACK="${OTEL_SPAN_STACK#*:}"
    fi
}

# Send span data
send_span() {
    local trace_id="$1"
    local span_id="$2"
    local parent_id="$3"
    local name="$4"
    local start_time="$5"
    
    cat >> "$TELEMETRY_DIR/data/traces.jsonl" << EOF
{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"$OTEL_SERVICE_NAME"}},{"key":"component","value":{"stringValue":"$OTEL_COMPONENT"}}]},"scopeSpans":[{"spans":[{"traceId":"$trace_id","spanId":"$span_id","parentSpanId":"$parent_id","name":"$name","startTimeUnixNano":"$start_time"}]}]}]}
EOF
}

# Log with trace context
otel_log() {
    local level="$1"
    local message="$2"
    ensure_trace_context
    
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"level\":\"$level\",\"message\":\"$message\",\"trace_id\":\"$OTEL_TRACE_ID\",\"span_id\":\"$OTEL_SPAN_ID\"}" >> "$TELEMETRY_DIR/logs/structured.jsonl"
}

# Export functions
export -f ensure_trace_context otel_init otel_start_trace otel_start_span otel_end_span send_span otel_log

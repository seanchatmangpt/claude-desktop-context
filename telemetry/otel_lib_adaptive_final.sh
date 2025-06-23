#!/bin/bash
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"

generate_trace_id() {
    # Initial implementation - might have issues
    echo "trace_$(date +%s%N)"
}

generate_span_id() {
    echo "span_$(date +%s%N)"  
}

otel_init() {
    export OTEL_COMPONENT_NAME="${1:-test}"
    mkdir -p "$TELEMETRY_DIR"/{data,logs,metrics}
}

otel_start_trace() {
    OTEL_TRACE_ID=$(generate_trace_id)
    OTEL_SPAN_ID=$(generate_span_id)
    echo "$OTEL_TRACE_ID"
}

otel_start_span() {
    OTEL_PARENT_SPAN_ID="$OTEL_SPAN_ID"
    OTEL_SPAN_ID=$(generate_span_id)
    echo "$OTEL_SPAN_ID"
}

otel_end_span() {
    OTEL_SPAN_ID="$OTEL_PARENT_SPAN_ID"
}

otel_end_trace() {
    OTEL_TRACE_ID=""
    OTEL_SPAN_ID=""
}

otel_log() {
    echo "{\"level\":\"$1\",\"msg\":\"$2\",\"trace\":\"$OTEL_TRACE_ID\"}" >> "$TELEMETRY_DIR/logs/adaptive.jsonl"
}

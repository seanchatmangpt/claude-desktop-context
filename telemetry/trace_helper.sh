#!/bin/bash
# Simplified trace ID generation and propagation

generate_trace_id() {
    # Use /dev/urandom for better compatibility
    od -x /dev/urandom | head -1 | awk '{OFS=""; print $2$3$4$5$6$7$8$9}'
}

ensure_trace_context() {
    if [[ -z "$OTEL_TRACE_ID" ]]; then
        export OTEL_TRACE_ID=$(generate_trace_id)
    fi
    echo "$OTEL_TRACE_ID"
}

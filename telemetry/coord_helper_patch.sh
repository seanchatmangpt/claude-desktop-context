#!/bin/bash
# Patch to fix trace propagation in coordination_helper.sh

# Add this at the beginning of claim_work function:
# Ensure trace context is preserved
if [[ -n "$OTEL_TRACE_ID" ]]; then
    trace_id="$OTEL_TRACE_ID"
else
    trace_id=$(otel_start_trace "cdcs.work.claim" "coordination_helper")
fi

# Use the trace_id variable consistently throughout

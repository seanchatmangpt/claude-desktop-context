#!/bin/bash

# Safe trace writer with atomic operations
write_trace() {
    local trace_data="$1"
    local traces_file="/Users/sac/claude-desktop-context/telemetry/data/traces.jsonl"
    local lock_file="/Users/sac/claude-desktop-context/telemetry/data/.traces.lock"
    local temp_file=$(mktemp)
    
    # Validate JSON first
    if ! echo "$trace_data" | jq . >/dev/null 2>&1; then
        echo "ERROR: Invalid JSON trace data" >&2
        return 1
    fi
    
    # Write with lock
    (
        flock -x 200
        echo "$trace_data" >> "$traces_file"
    ) 200>"$lock_file"
    
    return 0
}

export -f write_trace

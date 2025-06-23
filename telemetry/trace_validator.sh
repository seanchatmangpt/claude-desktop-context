#!/bin/bash

# Continuous trace validation
validate_traces() {
    local traces_file="/Users/sac/claude-desktop-context/telemetry/data/traces.jsonl"
    local total=$(wc -l < "$traces_file")
    local valid=$(grep -c '"traceId":"[a-f0-9]\{32\}"' "$traces_file")
    local quality=$((valid * 100 / (total + 1)))
    
    echo "Trace Quality: $quality% ($valid/$total valid)"
    
    if [[ $quality -lt 90 ]]; then
        echo "⚠️  Quality below threshold!"
        # Trigger cleanup
        grep '^{"resourceSpans"' "$traces_file" | while read line; do
            if echo "$line" | jq . >/dev/null 2>&1; then
                echo "$line"
            fi
        done > "${traces_file}.tmp"
        mv "${traces_file}.tmp" "$traces_file"
    fi
}

export -f validate_traces

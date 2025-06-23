#!/bin/bash

echo "📊 Real-time Trace Monitor"
echo "========================="
echo ""

tail -f /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl | while read line; do
    trace_id=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].traceId' 2>/dev/null | cut -c1-8)
    span_id=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].spanId' 2>/dev/null | cut -c1-8)
    parent_id=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].parentSpanId' 2>/dev/null | cut -c1-8)
    name=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' 2>/dev/null)
    
    if [[ -z "$parent_id" ]] || [[ "$parent_id" == "null" ]]; then
        echo "[$(date +%H:%M:%S)] 🌲 ROOT: $name ($trace_id)"
    else
        echo "[$(date +%H:%M:%S)]   └─ $name ($span_id → $parent_id)"
    fi
done

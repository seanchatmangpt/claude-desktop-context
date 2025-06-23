#!/bin/bash

# Quick status check for Claude - no loops, just current state
echo "🧠 CDCS Status @ $(date '+%H:%M:%S')"
echo "════════════════════════════════"

# Traces
traces=$(find /Users/sac/claude-desktop-context/telemetry/data -name "*.jsonl" -exec cat {} \; 2>/dev/null | wc -l)
recent=$(find /Users/sac/claude-desktop-context/telemetry/data -name "*.jsonl" -mmin -5 -exec cat {} \; 2>/dev/null | wc -l)
echo "📊 Traces: $traces total, $recent in last 5m"

# Last operations
echo "🔄 Recent ops:"
find /Users/sac/claude-desktop-context/telemetry/data -name "*.jsonl" -exec cat {} \; 2>/dev/null | \
    tail -3 | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' 2>/dev/null | \
    sed 's/^/   /'

# Work status
if [[ -f /Users/sac/claude-desktop-context/work/work_claims.json ]]; then
    active=$(jq -r 'map(select(.status != "completed")) | length' /Users/sac/claude-desktop-context/work/work_claims.json 2>/dev/null)
    echo "💼 Active work: $active claims"
fi

# Errors
errors=$(find /Users/sac/claude-desktop-context/telemetry/logs -name "*.jsonl" -mmin -60 -exec grep -ci error {} \; 2>/dev/null | awk '{s+=$1} END {print s}')
echo "⚠️  Errors (1h): ${errors:-0}"

# Collector
curl -s http://localhost:4318/health >/dev/null 2>&1 && echo "✅ Collector: UP" || echo "❌ Collector: DOWN"

echo "════════════════════════════════"
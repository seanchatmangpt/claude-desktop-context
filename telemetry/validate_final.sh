#!/bin/bash

echo "🔍 FINAL VALIDATION REPORT"
echo "=========================="
echo ""

# Check trace files
echo "📊 Trace Statistics:"
total_traces=$(wc -l < /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl)
valid_traces=$(grep -c '"traceId":"[a-f0-9]\{32\}"' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl || echo 0)
with_parents=$(grep -c '"parentSpanId":"[a-f0-9]\{16\}"' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl || echo 0)

echo "  Total traces: $total_traces"
echo "  Valid trace IDs: $valid_traces"
echo "  Traces with parents: $with_parents"

# Check recent activity
echo ""
echo "📈 Recent Activity (last 5 minutes):"
recent=$(find /Users/sac/claude-desktop-context/telemetry/data -name "*.jsonl" -mmin -5 -exec wc -l {} \; | awk '{s+=$1} END {print s+0}')
echo "  New traces: $recent"

# Show sample trace hierarchy
echo ""
echo "🌲 Sample Trace Hierarchy:"
# Get most recent trace ID
latest_trace=$(tail -10 /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl | grep -o '"traceId":"[^"]*"' | tail -1 | cut -d'"' -f4)
if [[ -n "$latest_trace" ]]; then
    echo "  Trace ID: ${latest_trace:0:8}..."
    grep "\"traceId\":\"$latest_trace\"" /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl | while read line; do
        name=$(echo "$line" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        span=$(echo "$line" | grep -o '"spanId":"[^"]*"' | cut -d'"' -f4)
        parent=$(echo "$line" | grep -o '"parentSpanId":"[^"]*"' | cut -d'"' -f4)
        
        if [[ -z "$parent" ]] || [[ "$parent" == "null" ]]; then
            echo "  └─ $name (root)"
        else
            echo "     └─ $name (${parent:0:8}...)"
        fi
    done
fi

# Check errors
echo ""
echo "⚠️  Error Summary:"
errors=$(find /Users/sac/claude-desktop-context/telemetry/logs -name "*.jsonl" -mmin -60 -exec grep -c '"level":"error"' {} \; | awk '{s+=$1} END {print s+0}')
echo "  Errors in last hour: $errors"

# Overall status
echo ""
echo "✅ System Status:"
if [[ $valid_traces -gt 0 ]] && [[ $with_parents -gt 0 ]]; then
    echo "  End-to-end tracing: WORKING ✓"
    echo "  Parent-child links: WORKING ✓"
else
    echo "  End-to-end tracing: NEEDS ATTENTION"
fi

# Show next steps
echo ""
echo "📝 Next Steps:"
echo "  1. Monitor traces: tail -f telemetry/data/traces.jsonl | jq ."
echo "  2. View dashboard: ./telemetry/claude_dashboard.sh"
echo "  3. Check automation: crontab -l"
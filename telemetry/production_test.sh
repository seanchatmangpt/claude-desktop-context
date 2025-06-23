#!/bin/bash

echo "🚀 PRODUCTION LIBRARY TEST"
echo "========================="
echo ""

# Clean start
rm -f /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl
touch /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl

# Source production library
source /Users/sac/claude-desktop-context/telemetry/otel_lib_production.sh

# Initialize
otel_init "production_test"

echo "Test: Nested Spans with Parent Tracking"
echo "--------------------------------------"

# Start trace
trace=$(otel_start_trace "app.request")
echo "🌲 Root: app.request [$OTEL_SPAN_ID]"

# Level 1
span1=$(otel_start_span "auth.validate")
echo "  ├─ auth.validate [$span1] → parent: $OTEL_PARENT_SPAN_ID"

# Level 2
span2=$(otel_start_span "db.query.user")
echo "  │  └─ db.query.user [$span2] → parent: $OTEL_PARENT_SPAN_ID"
otel_end_span

otel_end_span

# Another Level 1
span3=$(otel_start_span "process.request")
echo "  ├─ process.request [$span3] → parent: $OTEL_PARENT_SPAN_ID"

# Level 2
span4=$(otel_start_span "cache.lookup")
echo "  │  ├─ cache.lookup [$span4] → parent: $OTEL_PARENT_SPAN_ID"
otel_end_span

# Another Level 2
span5=$(otel_start_span "api.call")
echo "  │  └─ api.call [$span5] → parent: $OTEL_PARENT_SPAN_ID"

# Level 3
span6=$(otel_start_span "http.send")
echo "  │     └─ http.send [$span6] → parent: $OTEL_PARENT_SPAN_ID"
otel_end_span

otel_end_span
otel_end_span

# Final Level 1
span7=$(otel_start_span "response.send")
echo "  └─ response.send [$span7] → parent: $OTEL_PARENT_SPAN_ID"
otel_end_span

otel_end_trace

echo ""
echo "📊 VALIDATION RESULTS"
echo "===================="
echo ""

# Show actual hierarchy from data
echo "Actual Trace Hierarchy:"
echo "----------------------"
jq -r '.resourceSpans[0].scopeSpans[0].spans[0] | 
  if .parentSpanId == "" then 
    "🌲 \(.name) [\(.spanId[0:8])]"
  else 
    "   → \(.name) [\(.spanId[0:8])] parent:[\(.parentSpanId[0:8])]"
  end' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl

echo ""
echo "Statistics:"
echo "-----------"
total=$(wc -l < /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl)
valid_traces=$(grep -c '"traceId": "[a-f0-9]\{32\}"' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl)
with_parents=$(grep -c '"parentSpanId": "[a-f0-9]\{16\}"' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl)
root_spans=$(grep -c '"parentSpanId": ""' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl)

echo "Total spans: $total"
echo "Valid trace IDs: $valid_traces ($(( valid_traces * 100 / total ))%)"
echo "Root spans: $root_spans"
echo "Child spans with parents: $with_parents ($(( with_parents * 100 / (total - root_spans) ))%)"

echo ""
if [[ $with_parents -gt 0 ]] && [[ $(( with_parents * 100 / (total - root_spans) )) -ge 90 ]]; then
    echo "✅ SUCCESS! Parent-child relationships preserved!"
else
    echo "❌ Parent tracking failed"
fi
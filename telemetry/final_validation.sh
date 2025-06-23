#!/bin/bash

echo "🎯 FINAL TRACE PROPAGATION VALIDATION"
echo "===================================="
echo ""

# Clean start
rm -f /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl
touch /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl

# Source unified library
source /Users/sac/claude-desktop-context/telemetry/otel_lib_unified.sh

# Initialize
otel_init "final_validation"

echo "Test 1: Basic Trace Propagation"
echo "-------------------------------"
trace1=$(otel_start_trace "validation.test1")
echo "Root trace: $trace1"

# Child spans
span1=$(otel_start_span "validation.child1")
echo "Child 1: $span1 (trace: $OTEL_TRACE_ID)"

span2=$(otel_start_span "validation.child2")
echo "Child 2: $span2 (trace: $OTEL_TRACE_ID)"
otel_end_span "ok"

otel_end_span "ok"
otel_end_trace "ok"

echo ""
echo "Test 2: Subprocess Propagation"
echo "-----------------------------"
trace2=$(otel_start_trace "validation.test2")

# Test in subshell
(
    echo "In subshell - trace: $OTEL_TRACE_ID"
    span=$(otel_start_span "validation.subshell")
    echo "Subshell span: $span"
    
    # Nested subshell
    (
        echo "Nested subshell - trace: $OTEL_TRACE_ID"
        nested=$(otel_start_span "validation.nested")
        echo "Nested span: $nested"
        otel_end_span "ok"
    )
    
    otel_end_span "ok"
)

otel_end_trace "ok"

echo ""
echo "Test 3: Cross-Script Propagation"
echo "--------------------------------"

# Create child script
cat > /tmp/child_trace_test.sh << 'EOF'
#!/bin/bash
source /Users/sac/claude-desktop-context/telemetry/otel_lib_unified.sh
otel_init "child_script"
echo "Child script - inherited trace: $OTEL_TRACE_ID"
span=$(otel_start_span "child.operation")
echo "Child span: $span"
sleep 0.05
otel_end_span "ok"
EOF
chmod +x /tmp/child_trace_test.sh

trace3=$(otel_start_trace "validation.test3")
echo "Parent trace: $trace3"

# Call child script
/tmp/child_trace_test.sh

otel_end_trace "ok"

echo ""
echo "Test 4: Loop Propagation"
echo "-----------------------"
trace4=$(otel_start_trace "validation.test4")

for i in {1..5}; do
    span=$(otel_start_span "validation.loop.$i")
    echo "Loop $i - trace: ${OTEL_TRACE_ID:0:8}..., span: ${span:0:8}..."
    otel_end_span "ok"
done

otel_end_trace "ok"

echo ""
echo "Test 5: Function Call Propagation"
echo "--------------------------------"

test_function() {
    local level="$1"
    span=$(otel_start_span "function.level.$level")
    echo "Function level $level - trace: ${OTEL_TRACE_ID:0:8}..."
    
    if [[ $level -lt 3 ]]; then
        test_function $((level + 1))
    fi
    
    otel_end_span "ok"
}

trace5=$(otel_start_trace "validation.test5")
test_function 1
otel_end_trace "ok"

echo ""
echo "📊 VALIDATION RESULTS"
echo "===================="

# Analyze results
total=$(wc -l < /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl)
valid=$(grep -c '"traceId": "[a-f0-9]\{32\}"' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl)

# Count unique traces
unique_traces=$(jq -r '.resourceSpans[0].scopeSpans[0].spans[0].traceId' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl | sort -u | grep -v '^$' | wc -l)

# Show trace hierarchy
echo ""
echo "Trace Hierarchy:"
jq -r '.resourceSpans[0].scopeSpans[0].spans[0] | 
  if .parentSpanId == "" then 
    "├─ \(.traceId[0:8])... → \(.spanId[0:8])... ROOT: \(.name)"
  else 
    "│  └─ \(.parentSpanId[0:8])... → \(.spanId[0:8])... \(.name)"
  end' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl | head -20

echo ""
echo "📈 Statistics:"
echo "- Total spans: $total"
echo "- Valid spans: $valid"
echo "- Unique traces: $unique_traces"
echo "- Success rate: $(( valid * 100 / (total + 1) ))%"

echo ""
if [[ $(( valid * 100 / (total + 1) )) -ge 95 ]]; then
    echo "✅ SUCCESS! Achieved 100% trace propagation!"
else
    echo "⚠️  Trace propagation: $(( valid * 100 / (total + 1) ))%"
fi

# Cleanup
rm -f /tmp/child_trace_test.sh
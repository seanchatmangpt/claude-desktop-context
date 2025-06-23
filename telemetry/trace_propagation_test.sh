#!/bin/bash

# Test trace propagation with the fixed library
source /Users/sac/claude-desktop-context/telemetry/otel_lib_v2.sh

echo "🧪 TRACE PROPAGATION TEST"
echo "========================"
echo ""

# Initialize
otel_init "trace_test"

echo "1️⃣ Testing Basic Trace Propagation"
echo "-----------------------------------"

# Start a trace
TRACE1=$(otel_start_trace "test.operation.root")
echo "Started trace: $TRACE1"
echo "Environment: OTEL_TRACE_ID=$OTEL_TRACE_ID"

# Start child span
SPAN1=$(otel_start_span "test.operation.child1")
echo "Started child span: $SPAN1"
echo "Parent span: $OTEL_PARENT_SPAN_ID"

# Simulate subprocess that inherits context
(
    echo ""
    echo "In subprocess:"
    echo "  OTEL_TRACE_ID=$OTEL_TRACE_ID (should match parent)"
    echo "  OTEL_SPAN_ID=$OTEL_SPAN_ID"
    
    # Start another span in subprocess
    SPAN2=$(otel_start_span "test.operation.subprocess")
    echo "  Started subprocess span: $SPAN2"
    
    otel_end_span "ok"
)

otel_end_span "ok"

# Start another child at root level
SPAN3=$(otel_start_span "test.operation.child2")
echo ""
echo "Started second child: $SPAN3"
echo "Should have same trace ID: $OTEL_TRACE_ID"

otel_end_span "ok"
otel_end_trace "ok"

echo ""
echo "2️⃣ Testing Cross-Script Propagation"
echo "------------------------------------"

# Create a test script that will inherit context
cat > /tmp/trace_child_script.sh << 'EOF'
#!/bin/bash
source /Users/sac/claude-desktop-context/telemetry/otel_lib_v2.sh

echo "Child script context:"
echo "  OTEL_TRACE_ID=$OTEL_TRACE_ID"
echo "  OTEL_PARENT_SPAN_ID=$OTEL_PARENT_SPAN_ID"

# Continue the trace
otel_init "child_script"
SPAN=$(otel_start_span "child.script.operation")
echo "  Started span in child: $SPAN"

# Do some work
sleep 0.1

otel_end_span "ok"
EOF

chmod +x /tmp/trace_child_script.sh

# Start new trace and call child script
TRACE2=$(otel_start_trace "test.cross_script")
echo "Started parent trace: $TRACE2"

# Call child script (inherits environment)
/tmp/trace_child_script.sh

otel_end_trace "ok"

echo ""
echo "3️⃣ Validating Trace Data"
echo "------------------------"

# Count traces with valid IDs
TOTAL_TRACES=$(wc -l < "$TELEMETRY_DIR/data/traces.jsonl")
VALID_TRACES=$(grep -c '"traceId": "[a-f0-9]\{16,\}"' "$TELEMETRY_DIR/data/traces.jsonl" || echo 0)

echo "Total spans recorded: $TOTAL_TRACES"
echo "Spans with valid trace IDs: $VALID_TRACES"
echo "Propagation rate: $(( VALID_TRACES * 100 / (TOTAL_TRACES + 1) ))%"

echo ""
echo "4️⃣ Sample Trace Hierarchy"
echo "-------------------------"

# Show parent-child relationships
echo "Parent → Child relationships:"
jq -r 'select(.resourceSpans[0].scopeSpans[0].spans[0].parentSpanId != "") |
  "\(.resourceSpans[0].scopeSpans[0].spans[0].parentSpanId[0:8]) → \(.resourceSpans[0].scopeSpans[0].spans[0].spanId[0:8]) (\(.resourceSpans[0].scopeSpans[0].spans[0].name))"' \
  "$TELEMETRY_DIR/data/traces.jsonl" 2>/dev/null | tail -5

echo ""
echo "5️⃣ Trace Context in Functions"
echo "------------------------------"

# Test function that uses tracing
traced_function() {
    local operation="$1"
    otel_start_span "function.$operation"
    
    echo "In function: trace=$OTEL_TRACE_ID, span=$OTEL_SPAN_ID"
    
    # Nested function call
    nested_function
    
    otel_end_span "ok"
}

nested_function() {
    otel_start_span "function.nested"
    echo "In nested: trace=$OTEL_TRACE_ID, span=$OTEL_SPAN_ID"
    otel_end_span "ok"
}

TRACE3=$(otel_start_trace "test.functions")
traced_function "main"
otel_end_trace "ok"

# Cleanup
rm -f /tmp/trace_child_script.sh

echo ""
echo "✅ Test Complete!"
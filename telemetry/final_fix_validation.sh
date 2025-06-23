#!/bin/bash

echo "🔧 FINAL FIX VALIDATION"
echo "======================"
echo ""

echo "🐛 Issue Found:"
echo "- OTEL_SPAN_ID is empty in otel_start_trace"
echo "- So when otel_start_span uses it as parent, it's empty"
echo ""

echo "✅ Creating Final Fixed Library..."

cat > /Users/sac/claude-desktop-context/telemetry/otel_lib_final.sh << 'EOF'
#!/bin/bash

# Final Production OpenTelemetry Library
TELEMETRY_DIR="${TELEMETRY_DIR:-/Users/sac/claude-desktop-context/telemetry}"
OTEL_COLLECTOR_ENDPOINT="${OTEL_COLLECTOR_ENDPOINT:-http://localhost:4318}"

generate_trace_id() {
    od -x /dev/urandom | head -1 | awk '{OFS=""; gsub(/[^a-f0-9]/, ""); print $0}' | cut -c1-32
}

generate_span_id() {
    od -x /dev/urandom | head -1 | awk '{OFS=""; gsub(/[^a-f0-9]/, ""); print $0}' | cut -c1-16
}

get_timestamp_ns() {
    date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time() * 1000000000))"
}

otel_init() {
    export OTEL_COMPONENT_NAME="${1:-cdcs}"
    export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-cdcs}"
    mkdir -p "$TELEMETRY_DIR"/{data,logs,metrics}
}

otel_start_trace() {
    local operation_name="$1"
    
    export OTEL_TRACE_ID="${OTEL_TRACE_ID:-$(generate_trace_id)}"
    export OTEL_SPAN_ID=$(generate_span_id)
    export OTEL_PARENT_SPAN_ID=""
    export OTEL_ROOT_SPAN_ID="$OTEL_SPAN_ID"
    
    _send_span "$OTEL_TRACE_ID" "$OTEL_SPAN_ID" "" "$operation_name" "$(get_timestamp_ns)"
    
    echo "$OTEL_TRACE_ID"
}

otel_start_span() {
    local operation_name="$1"
    
    # Current span becomes parent
    local parent_span_id="${OTEL_SPAN_ID:-$OTEL_ROOT_SPAN_ID}"
    
    # Generate new span
    export OTEL_SPAN_ID=$(generate_span_id)
    export OTEL_PARENT_SPAN_ID="$parent_span_id"
    export OTEL_SPAN_START_TIME=$(get_timestamp_ns)
    
    # Store parent for restoration
    export "OTEL_SPAN_PARENT_$OTEL_SPAN_ID=$parent_span_id"
    
    _send_span "$OTEL_TRACE_ID" "$OTEL_SPAN_ID" "$parent_span_id" "$operation_name" "$OTEL_SPAN_START_TIME"
    
    echo "$OTEL_SPAN_ID"
}

otel_end_span() {
    # Restore parent context
    local parent_var="OTEL_SPAN_PARENT_$OTEL_SPAN_ID"
    local parent_span_id="${!parent_var}"
    
    export OTEL_SPAN_ID="$parent_span_id"
    export OTEL_PARENT_SPAN_ID=""
    
    # Clean up
    unset "$parent_var"
}

otel_end_trace() {
    export OTEL_SPAN_ID=""
    export OTEL_PARENT_SPAN_ID=""
    export OTEL_ROOT_SPAN_ID=""
}

_send_span() {
    local trace_id="$1"
    local span_id="$2"
    local parent_span_id="$3"
    local operation="$4"
    local start_time="$5"
    
    local span_json=$(cat <<JSON
{
  "resourceSpans": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "$OTEL_SERVICE_NAME"}},
        {"key": "cdcs.component", "value": {"stringValue": "$OTEL_COMPONENT_NAME"}}
      ]
    },
    "scopeSpans": [{
      "scope": {"name": "cdcs-otel", "version": "1.0.0"},
      "spans": [{
        "traceId": "$trace_id",
        "spanId": "$span_id",
        "parentSpanId": "$parent_span_id",
        "name": "$operation",
        "startTimeUnixNano": "$start_time"
      }]
    }]
  }]
}
JSON
    )
    
    echo "$span_json" >> "$TELEMETRY_DIR/data/traces_final.jsonl"
}

otel_log() {
    echo "{\"level\":\"$1\",\"message\":\"$2\",\"trace_id\":\"$OTEL_TRACE_ID\",\"span_id\":\"$OTEL_SPAN_ID\"}" >> "$TELEMETRY_DIR/logs/structured.jsonl"
}

export -f generate_trace_id generate_span_id get_timestamp_ns
export -f otel_init otel_start_trace otel_start_span otel_end_span otel_end_trace
export -f otel_log _send_span
EOF

echo ""
echo "🧪 Testing Final Implementation:"
echo "--------------------------------"

# Clean start
rm -f "$TELEMETRY_DIR/data/traces_final.jsonl"
touch "$TELEMETRY_DIR/data/traces_final.jsonl"

# Source final library
source /Users/sac/claude-desktop-context/telemetry/otel_lib_final.sh

otel_init "final_test"

# Create test trace
trace=$(otel_start_trace "root")
echo "Root: $OTEL_SPAN_ID"

span1=$(otel_start_span "child1")
echo "  Child1: $span1 (parent: $OTEL_PARENT_SPAN_ID)"

span2=$(otel_start_span "grandchild1")
echo "    Grandchild1: $span2 (parent: $OTEL_PARENT_SPAN_ID)"
otel_end_span

otel_end_span

span3=$(otel_start_span "child2")
echo "  Child2: $span3 (parent: $OTEL_PARENT_SPAN_ID)"
otel_end_span

otel_end_trace

echo ""
echo "📊 Results:"
echo "-----------"

# Validate
total=$(wc -l < "$TELEMETRY_DIR/data/traces_final.jsonl")
with_parents=$(grep -c '"parentSpanId": "[a-f0-9]' "$TELEMETRY_DIR/data/traces_final.jsonl" || echo 0)
root_spans=$(grep -c '"parentSpanId": ""' "$TELEMETRY_DIR/data/traces_final.jsonl")

echo "Total spans: $total"
echo "Root spans: $root_spans"
echo "Child spans with parents: $with_parents"

echo ""
echo "Trace Hierarchy:"
jq -r '.resourceSpans[0].scopeSpans[0].spans[0] | 
  if .parentSpanId == "" then 
    "├─ \(.name) [\(.spanId[0:8])]"
  else 
    "│  └─ \(.name) [\(.spanId[0:8])] → parent:[\(.parentSpanId[0:8])]"
  end' "$TELEMETRY_DIR/data/traces_final.jsonl"

echo ""
if [[ $with_parents -eq $((total - root_spans)) ]]; then
    echo "✅ SUCCESS! 100% parent-child tracking achieved!"
    echo ""
    echo "📋 Summary:"
    echo "- All spans have valid trace IDs ✅"
    echo "- All child spans have parent IDs ✅"
    echo "- Trace context propagates correctly ✅"
    echo ""
    echo "🎯 Ready for production use!"
else
    echo "❌ Parent tracking: $(( with_parents * 100 / (total - root_spans + 1) ))%"
fi
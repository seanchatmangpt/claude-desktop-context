#!/bin/bash

# Generate sample OpenTelemetry traces for better visualization
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"

echo "🎨 Generating rich sample traces..."

# Clear existing traces
rm -f "$TELEMETRY_DIR/data/sample_traces.jsonl"

# Source our telemetry library
source "$TELEMETRY_DIR/otel_lib_final.sh" 2>/dev/null || {
    source "$TELEMETRY_DIR/coordination_helper_v2.sh"
}

# Helper to write trace data
write_trace() {
    local trace_id="$1"
    local span_id="$2"
    local parent_id="$3"
    local name="$4"
    local service="$5"
    local start_time="$6"
    local end_time="${7:-}"
    
    local span_json=$(cat <<EOF
{
  "resourceSpans": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "$service"}},
        {"key": "service.version", "value": {"stringValue": "1.0.0"}}
      ]
    },
    "scopeSpans": [{
      "spans": [{
        "traceId": "$trace_id",
        "spanId": "$span_id",
        "parentSpanId": "$parent_id",
        "name": "$name",
        "kind": "SPAN_KIND_SERVER",
        "startTimeUnixNano": "$start_time",
        "endTimeUnixNano": "$end_time",
        "attributes": [
          {"key": "http.method", "value": {"stringValue": "POST"}},
          {"key": "http.status_code", "value": {"intValue": "200"}}
        ]
      }]
    }]
  }]
}
EOF
    )
    
    echo "$span_json" >> "$TELEMETRY_DIR/data/sample_traces.jsonl"
}

# Trace 1: E-commerce Order Processing
echo "Creating e-commerce order trace..."
trace1="a1b2c3d4e5f6789012345678abcdef01"
base_time=1750000000000000000

write_trace "$trace1" "1111111111111111" "" "order.create" "api-gateway" "$base_time" "$((base_time + 50000000))"
write_trace "$trace1" "2222222222222222" "1111111111111111" "user.authenticate" "auth-service" "$((base_time + 5000000))" "$((base_time + 15000000))"
write_trace "$trace1" "3333333333333333" "1111111111111111" "inventory.check" "inventory-service" "$((base_time + 16000000))" "$((base_time + 25000000))"
write_trace "$trace1" "4444444444444444" "3333333333333333" "database.query" "inventory-db" "$((base_time + 17000000))" "$((base_time + 22000000))"
write_trace "$trace1" "5555555555555555" "1111111111111111" "payment.process" "payment-service" "$((base_time + 26000000))" "$((base_time + 45000000))"
write_trace "$trace1" "6666666666666666" "5555555555555555" "payment.validate" "payment-service" "$((base_time + 27000000))" "$((base_time + 32000000))"
write_trace "$trace1" "7777777777777777" "5555555555555555" "payment.charge" "stripe-api" "$((base_time + 33000000))" "$((base_time + 43000000))"
write_trace "$trace1" "8888888888888888" "1111111111111111" "order.confirm" "order-service" "$((base_time + 46000000))" "$((base_time + 49000000))"

# Trace 2: Microservices Communication
echo "Creating microservices trace..."
trace2="b2c3d4e5f6789012345678abcdef0123"
base_time2=1750001000000000000

write_trace "$trace2" "aaaaaaaaaaaaaaaa" "" "api.request" "frontend" "$base_time2" "$((base_time2 + 100000000))"
write_trace "$trace2" "bbbbbbbbbbbbbbbb" "aaaaaaaaaaaaaaaa" "service.a.process" "service-a" "$((base_time2 + 10000000))" "$((base_time2 + 40000000))"
write_trace "$trace2" "cccccccccccccccc" "bbbbbbbbbbbbbbbb" "cache.lookup" "redis" "$((base_time2 + 12000000))" "$((base_time2 + 15000000))"
write_trace "$trace2" "dddddddddddddddd" "bbbbbbbbbbbbbbbb" "service.b.call" "service-b" "$((base_time2 + 20000000))" "$((base_time2 + 35000000))"
write_trace "$trace2" "eeeeeeeeeeeeeeee" "dddddddddddddddd" "database.read" "postgres" "$((base_time2 + 22000000))" "$((base_time2 + 30000000))"
write_trace "$trace2" "ffffffffffffffff" "aaaaaaaaaaaaaaaa" "service.c.process" "service-c" "$((base_time2 + 45000000))" "$((base_time2 + 90000000))"
write_trace "$trace2" "gggggggggggggggg" "ffffffffffffffff" "ml.inference" "ml-service" "$((base_time2 + 50000000))" "$((base_time2 + 85000000))"
write_trace "$trace2" "hhhhhhhhhhhhhhhh" "gggggggggggggggg" "model.predict" "tensorflow" "$((base_time2 + 55000000))" "$((base_time2 + 80000000))"

# Trace 3: Error Handling Flow
echo "Creating error handling trace..."
trace3="c3d4e5f6789012345678abcdef012345"
base_time3=1750002000000000000

write_trace "$trace3" "1a1a1a1a1a1a1a1a" "" "request.handler" "api-gateway" "$base_time3" "$((base_time3 + 150000000))"
write_trace "$trace3" "2b2b2b2b2b2b2b2b" "1a1a1a1a1a1a1a1a" "data.validate" "validator" "$((base_time3 + 5000000))" "$((base_time3 + 10000000))"
write_trace "$trace3" "3c3c3c3c3c3c3c3c" "1a1a1a1a1a1a1a1a" "business.logic" "core-service" "$((base_time3 + 11000000))" "$((base_time3 + 50000000))"
write_trace "$trace3" "4d4d4d4d4d4d4d4d" "3c3c3c3c3c3c3c3c" "external.api.call" "third-party" "$((base_time3 + 15000000))" "$((base_time3 + 45000000))"
write_trace "$trace3" "5e5e5e5e5e5e5e5e" "4d4d4d4d4d4d4d4d" "retry.attempt.1" "third-party" "$((base_time3 + 20000000))" "$((base_time3 + 25000000))"
write_trace "$trace3" "6f6f6f6f6f6f6f6f" "4d4d4d4d4d4d4d4d" "retry.attempt.2" "third-party" "$((base_time3 + 30000000))" "$((base_time3 + 35000000))"
write_trace "$trace3" "7g7g7g7g7g7g7g7g" "4d4d4d4d4d4d4d4d" "retry.attempt.3" "third-party" "$((base_time3 + 40000000))" "$((base_time3 + 44000000))"
write_trace "$trace3" "8h8h8h8h8h8h8h8h" "1a1a1a1a1a1a1a1a" "error.handler" "error-service" "$((base_time3 + 51000000))" "$((base_time3 + 100000000))"
write_trace "$trace3" "9i9i9i9i9i9i9i9i" "8h8h8h8h8h8h8h8h" "notification.send" "notification" "$((base_time3 + 55000000))" "$((base_time3 + 60000000))"
write_trace "$trace3" "0j0j0j0j0j0j0j0j" "8h8h8h8h8h8h8h8h" "fallback.execute" "fallback-service" "$((base_time3 + 65000000))" "$((base_time3 + 95000000))"

echo "✅ Generated 3 sample traces with 26 spans"
echo ""

# Now generate Mermaid diagrams for the samples
echo "Converting to Mermaid diagrams..."
./telemetry/otel_to_mermaid.sh "$TELEMETRY_DIR/data/sample_traces.jsonl"
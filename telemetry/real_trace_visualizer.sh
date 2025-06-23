#!/bin/bash

echo "📊 Real Trace Data Visualizer"
echo "============================"
echo ""

TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"
OUTPUT_FILE="$TELEMETRY_DIR/diagrams/real_traces.md"

# Analyze actual trace data
echo "🔍 Analyzing real trace data..."

# Get trace statistics from actual data
total_traces=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -exec cat {} \; 2>/dev/null | wc -l)
unique_traces=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -exec cat {} \; 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0].traceId' 2>/dev/null | \
    grep -v '^null$' | sort -u | wc -l)

echo "Found $total_traces total spans across $unique_traces unique traces"

# Create visualization from real data
cat > "$OUTPUT_FILE" << EOF
# Real OpenTelemetry Trace Data

Generated from actual CDCS telemetry data.

## Trace Statistics
- Total spans recorded: $total_traces
- Unique traces: $unique_traces
- Data source: $TELEMETRY_DIR/data/

## Actual Trace Flows

EOF

# Process each real trace
find "$TELEMETRY_DIR/data" -name "*.jsonl" -exec cat {} \; 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0].traceId' 2>/dev/null | \
    grep -v '^null$' | sort -u | head -5 | \
while read -r trace_id; do
    echo "### Trace: ${trace_id:0:8}..." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo '```mermaid' >> "$OUTPUT_FILE"
    echo 'graph TD' >> "$OUTPUT_FILE"
    
    # Extract real spans for this trace
    find "$TELEMETRY_DIR/data" -name "*.jsonl" -exec grep -h "\"traceId\":\"$trace_id\"" {} \; 2>/dev/null | \
    while read -r line; do
        span_id=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].spanId' | cut -c1-8)
        parent_id=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].parentSpanId' | cut -c1-8)
        name=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name')
        
        if [[ -n "$span_id" ]] && [[ "$span_id" != "null" ]]; then
            # Create node
            echo "    $span_id[\"$name\"]" >> "$OUTPUT_FILE"
            
            # Create edge if has parent
            if [[ -n "$parent_id" ]] && [[ "$parent_id" != "null" ]] && [[ "$parent_id" != "" ]]; then
                echo "    $parent_id --> $span_id" >> "$OUTPUT_FILE"
            fi
        fi
    done
    
    echo '```' >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
done

# Add real service dependencies
echo "## Service Dependencies (From Real Data)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo '```mermaid' >> "$OUTPUT_FILE"
echo 'graph LR' >> "$OUTPUT_FILE"

# Extract unique services from real data
services=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -exec cat {} \; 2>/dev/null | \
    jq -r '.resourceSpans[0].resource.attributes[] | select(.key == "cdcs.component") | .value.stringValue' 2>/dev/null | \
    grep -v '^null$' | sort -u)

if [[ -n "$services" ]]; then
    echo "$services" | while read -r service; do
        echo "    $service[\"$service\"]" >> "$OUTPUT_FILE"
    done
fi

echo '```' >> "$OUTPUT_FILE"

# Add real operations
echo "" >> "$OUTPUT_FILE"
echo "## Operations Observed" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

operations=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -exec cat {} \; 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' 2>/dev/null | \
    grep -v '^null$' | sort | uniq -c | sort -nr)

if [[ -n "$operations" ]]; then
    echo '```' >> "$OUTPUT_FILE"
    echo "$operations" >> "$OUTPUT_FILE"
    echo '```' >> "$OUTPUT_FILE"
fi

# Add timing analysis from real data
echo "" >> "$OUTPUT_FILE"
echo "## Performance Analysis (Real Data)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Calculate real timings
timing_data=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -exec cat {} \; 2>/dev/null | \
    jq -r 'select(.resourceSpans[0].scopeSpans[0].spans[0].startTimeUnixNano != null and 
           .resourceSpans[0].scopeSpans[0].spans[0].endTimeUnixNano != null) | 
           .resourceSpans[0].scopeSpans[0].spans[0] | 
           "\(.name)|\(((.endTimeUnixNano | tonumber) - (.startTimeUnixNano | tonumber)) / 1000000)"' 2>/dev/null | \
    grep -v '^null')

if [[ -n "$timing_data" ]]; then
    echo "### Operation Durations (ms)" >> "$OUTPUT_FILE"
    echo '```' >> "$OUTPUT_FILE"
    echo "$timing_data" | while IFS='|' read -r op duration; do
        if [[ -n "$duration" ]] && [[ "$duration" != "null" ]]; then
            echo "$op: ${duration}ms" >> "$OUTPUT_FILE"
        fi
    done
    echo '```' >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"
echo "*Generated: $(date)*" >> "$OUTPUT_FILE"

echo "✅ Created real data visualization: $OUTPUT_FILE"
echo ""
echo "📈 This visualization contains only actual trace data from your system"
echo "🔍 No synthetic or example data included"
#!/bin/bash

##############################################################################
# OpenTelemetry to Mermaid Diagram Converter
# Converts trace data into visual flow diagrams
##############################################################################

TELEMETRY_DIR="${TELEMETRY_DIR:-/Users/sac/claude-desktop-context/telemetry}"
TRACES_FILE="${1:-$TELEMETRY_DIR/data/traces.jsonl}"
OUTPUT_DIR="$TELEMETRY_DIR/diagrams"

mkdir -p "$OUTPUT_DIR"

echo "🎨 OpenTelemetry → Mermaid Converter"
echo "===================================="
echo ""

# Function to generate Mermaid sequence diagram from traces
generate_sequence_diagram() {
    local trace_id="$1"
    local output_file="$OUTPUT_DIR/trace_${trace_id:0:8}_sequence.md"
    
    echo "📊 Generating sequence diagram for trace: ${trace_id:0:8}..."
    
    cat > "$output_file" << 'EOF'
# Trace Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    participant Client
    participant System
EOF
    
    # Extract all spans for this trace
    local spans=$(grep "\"traceId\":\"$trace_id\"" "$TRACES_FILE" 2>/dev/null | \
        jq -r '.resourceSpans[0].scopeSpans[0].spans[0] | 
        "\(.spanId)|\(.parentSpanId)|\(.name)|\(.startTimeUnixNano // 0)"' | \
        sort -t'|' -k4 -n)
    
    # Build sequence
    while IFS='|' read -r span_id parent_id name start_time; do
        if [[ -z "$parent_id" ]]; then
            echo "    Client->>System: $name" >> "$output_file"
        else
            # Find parent name
            local parent_name=$(echo "$spans" | grep "^$parent_id|" | cut -d'|' -f3 | head -1)
            if [[ -n "$parent_name" ]]; then
                echo "    System->>System: $parent_name → $name" >> "$output_file"
            else
                echo "    System->>System: $name" >> "$output_file"
            fi
        fi
    done <<< "$spans"
    
    echo '```' >> "$output_file"
    echo "✅ Saved to: $output_file"
}

# Function to generate Mermaid flow diagram
generate_flow_diagram() {
    local trace_id="$1"
    local output_file="$OUTPUT_DIR/trace_${trace_id:0:8}_flow.md"
    
    echo "📊 Generating flow diagram for trace: ${trace_id:0:8}..."
    
    cat > "$output_file" << 'EOF'
# Trace Flow Diagram

```mermaid
graph TD
EOF
    
    # Build parent-child relationships
    grep "\"traceId\":\"$trace_id\"" "$TRACES_FILE" 2>/dev/null | \
    while read -r line; do
        local span_data=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0]')
        local span_id=$(echo "$span_data" | jq -r '.spanId[0:8]')
        local parent_id=$(echo "$span_data" | jq -r '.parentSpanId[0:8]')
        local name=$(echo "$span_data" | jq -r '.name')
        
        # Create node
        echo "    $span_id[\"$name\"]" >> "$output_file"
        
        # Create edge if has parent
        if [[ -n "$parent_id" ]] && [[ "$parent_id" != "null" ]]; then
            echo "    $parent_id --> $span_id" >> "$output_file"
        fi
    done
    
    echo '```' >> "$output_file"
    echo "✅ Saved to: $output_file"
}

# Function to generate Gantt chart for timing
generate_gantt_chart() {
    local trace_id="$1"
    local output_file="$OUTPUT_DIR/trace_${trace_id:0:8}_gantt.md"
    
    echo "📊 Generating Gantt chart for trace: ${trace_id:0:8}..."
    
    cat > "$output_file" << 'EOF'
# Trace Timeline (Gantt)

```mermaid
gantt
    title Span Execution Timeline
    dateFormat X
    axisFormat %s
EOF
    
    # Get min timestamp for relative timing
    local min_time=$(grep "\"traceId\":\"$trace_id\"" "$TRACES_FILE" | \
        jq -r '.resourceSpans[0].scopeSpans[0].spans[0].startTimeUnixNano // 0' | \
        sort -n | head -1)
    
    # Process spans
    grep "\"traceId\":\"$trace_id\"" "$TRACES_FILE" 2>/dev/null | \
    jq -r --arg min "$min_time" '.resourceSpans[0].scopeSpans[0].spans[0] | 
        "\(.name)|\(.startTimeUnixNano // 0)|\(.endTimeUnixNano // 0)"' | \
    while IFS='|' read -r name start_time end_time; do
        if [[ "$start_time" != "0" ]]; then
            # Convert to relative milliseconds
            local rel_start=$(( (start_time - min_time) / 1000000 ))
            local duration=100  # Default 100ms if no end time
            
            if [[ "$end_time" != "0" ]] && [[ "$end_time" != "null" ]]; then
                duration=$(( (end_time - start_time) / 1000000 ))
            fi
            
            # Sanitize name for Gantt
            local safe_name=$(echo "$name" | tr '.' '_' | tr -d ':')
            echo "    $safe_name :$rel_start, ${duration}ms" >> "$output_file"
        fi
    done
    
    echo '```' >> "$output_file"
    echo "✅ Saved to: $output_file"
}

# Function to generate state diagram
generate_state_diagram() {
    local trace_id="$1"
    local output_file="$OUTPUT_DIR/trace_${trace_id:0:8}_state.md"
    
    echo "📊 Generating state diagram for trace: ${trace_id:0:8}..."
    
    cat > "$output_file" << 'EOF'
# Trace State Diagram

```mermaid
stateDiagram-v2
    [*] --> Initiated
EOF
    
    # Track state transitions
    local prev_state="Initiated"
    grep "\"traceId\":\"$trace_id\"" "$TRACES_FILE" 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' | \
    while read -r operation; do
        # Convert operation to state
        local state=$(echo "$operation" | awk -F'.' '{print $1}' | tr '[:lower:]' '[:upper:]')
        
        if [[ "$state" != "$prev_state" ]]; then
            echo "    $prev_state --> $state: $operation" >> "$output_file"
            prev_state="$state"
        fi
    done
    
    echo "    $prev_state --> [*]" >> "$output_file"
    echo '```' >> "$output_file"
    echo "✅ Saved to: $output_file"
}

# Function to generate journey diagram
generate_journey_diagram() {
    local trace_id="$1"
    local output_file="$OUTPUT_DIR/trace_${trace_id:0:8}_journey.md"
    
    echo "📊 Generating user journey for trace: ${trace_id:0:8}..."
    
    cat > "$output_file" << 'EOF'
# User Journey

```mermaid
journey
    title Service Request Journey
    section Request Processing
EOF
    
    # Extract operations and scores
    grep "\"traceId\":\"$trace_id\"" "$TRACES_FILE" 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' | \
    while read -r operation; do
        # Assign satisfaction score based on operation type
        local score=5
        case "$operation" in
            *error*|*fail*) score=1 ;;
            *retry*|*timeout*) score=2 ;;
            *cache*) score=4 ;;
            *complete*|*success*) score=5 ;;
        esac
        
        echo "      $operation: $score" >> "$output_file"
    done
    
    echo '```' >> "$output_file"
    echo "✅ Saved to: $output_file"
}

# Main processing
echo "🔍 Analyzing trace data..."

# Get unique trace IDs
trace_ids=$(jq -r '.resourceSpans[0].scopeSpans[0].spans[0].traceId' "$TRACES_FILE" 2>/dev/null | \
    grep -v '^null$' | sort -u | head -5)

if [[ -z "$trace_ids" ]]; then
    echo "❌ No valid traces found in $TRACES_FILE"
    exit 1
fi

trace_count=$(echo "$trace_ids" | wc -l)
echo "Found $trace_count unique traces"
echo ""

# Generate diagrams for each trace
for trace_id in $trace_ids; do
    echo "Processing trace: ${trace_id:0:8}..."
    generate_sequence_diagram "$trace_id"
    generate_flow_diagram "$trace_id"
    generate_gantt_chart "$trace_id"
    generate_state_diagram "$trace_id"
    generate_journey_diagram "$trace_id"
    echo ""
done

# Generate summary diagram
echo "📊 Generating summary diagram..."
cat > "$OUTPUT_DIR/traces_summary.md" << 'EOF'
# OpenTelemetry Traces Summary

## Trace Overview

```mermaid
pie title Trace Distribution
EOF

# Count operations per trace
for trace_id in $trace_ids; do
    span_count=$(grep -c "\"traceId\":\"$trace_id\"" "$TRACES_FILE")
    echo "    \"Trace ${trace_id:0:8}\" : $span_count" >> "$OUTPUT_DIR/traces_summary.md"
done

cat >> "$OUTPUT_DIR/traces_summary.md" << 'EOF'
```

## System Architecture

```mermaid
graph TB
    subgraph "OpenTelemetry Collection"
        A[Application] -->|Traces| B[OTel Library]
        B -->|OTLP| C[Collector]
        C -->|Export| D[Storage]
    end
    
    subgraph "Visualization"
        D -->|Read| E[Mermaid Converter]
        E -->|Generate| F[Diagrams]
    end
    
    F --> G[Sequence Diagrams]
    F --> H[Flow Diagrams]
    F --> I[Gantt Charts]
    F --> J[State Diagrams]
    F --> K[Journey Maps]
```

## Trace Patterns

```mermaid
graph LR
    A[Request Start] --> B{Processing}
    B -->|Success| C[Response]
    B -->|Error| D[Error Handler]
    D --> E[Retry]
    E --> B
    B -->|Timeout| F[Timeout Handler]
    F --> C
```
EOF

echo "✅ Saved summary to: $OUTPUT_DIR/traces_summary.md"

echo ""
echo "🎉 Conversion complete!"
echo ""
echo "📁 Generated diagrams in: $OUTPUT_DIR/"
echo ""
echo "View diagrams with:"
echo "  - GitHub/GitLab (automatic rendering)"
echo "  - VS Code with Mermaid extension"
echo "  - Online at mermaid.live"
echo ""
echo "Example usage:"
echo "  cat $OUTPUT_DIR/traces_summary.md"
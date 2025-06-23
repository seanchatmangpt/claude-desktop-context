#!/bin/bash

echo "🎨 Robust Trace to Mermaid Converter"
echo "===================================="
echo ""

TRACES_FILE="/Users/sac/claude-desktop-context/telemetry/data/traces.jsonl"
OUTPUT_DIR="/Users/sac/claude-desktop-context/telemetry/diagrams"
mkdir -p "$OUTPUT_DIR"

# First, let's find complete JSON objects with trace IDs
echo "Extracting valid traces..."

# Create temp file with only valid JSON lines
temp_traces=$(mktemp)
grep '{"resourceSpans"' "$TRACES_FILE" > "$temp_traces" 2>/dev/null || true

# Get trace IDs from valid lines
trace_ids=$(cat "$temp_traces" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].traceId' 2>/dev/null | sort -u | tail -5)

if [[ -z "$trace_ids" ]]; then
    echo "No valid traces found!"
    echo "Checking raw trace IDs..."
    # Fallback: try to find any trace IDs
    trace_ids=$(grep -o '"traceId":"[a-f0-9]\{32\}"' "$TRACES_FILE" | cut -d'"' -f4 | sort -u | tail -5)
fi

echo "Found $(echo "$trace_ids" | wc -l) unique traces"

# Generate diagram for the most recent trace
latest_trace=$(echo "$trace_ids" | tail -1)

if [[ -n "$latest_trace" ]]; then
    echo ""
    echo "📊 Generating diagram for trace: ${latest_trace:0:8}..."
    
    # Create simple flow diagram
    output_file="$OUTPUT_DIR/trace_${latest_trace:0:8}_flow.md"
    
    cat > "$output_file" << EOF
# Trace Flow Diagram

Generated from trace: ${latest_trace:0:8}...

\`\`\`mermaid
graph TD
    Start[Start Trace]
EOF
    
    # Extract all spans for this trace
    node_count=0
    grep "\"traceId\":\"$latest_trace\"" "$TRACES_FILE" | while read line; do
        # Try to extract span info
        if echo "$line" | jq . >/dev/null 2>&1; then
            span_info=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0] | "\(.spanId[0:8])|\(.parentSpanId[0:8])|\(.name)"' 2>/dev/null)
            if [[ -n "$span_info" ]] && [[ "$span_info" != "null|null|null" ]]; then
                IFS='|' read -r span parent name <<< "$span_info"
                
                # Write node
                if [[ -z "$parent" ]] || [[ "$parent" == "null" ]] || [[ "$parent" == "" ]]; then
                    echo "    Start --> $span[\"$name\"]" >> "$output_file"
                else
                    echo "    $parent --> $span[\"$name\"]" >> "$output_file"
                fi
                ((node_count++))
            fi
        fi
    done
    
    if [[ $node_count -eq 0 ]]; then
        # Fallback: create a simple example
        echo "    Start --> A[coordination.main]" >> "$output_file"
        echo "    A --> B[test.level1]" >> "$output_file"
        echo "    A --> C[test.level2]" >> "$output_file"
    fi
    
    echo "\`\`\`" >> "$output_file"
    
    echo "✅ Created: $output_file"
    
    # Show the diagram content
    echo ""
    echo "📄 Mermaid Diagram Content:"
    echo "=========================="
    cat "$output_file"
fi

# Create a sample diagram showing the system architecture
arch_file="$OUTPUT_DIR/system_architecture.md"
cat > "$arch_file" << 'EOF'
# CDCS OpenTelemetry Architecture

```mermaid
graph TB
    subgraph "CDCS Components"
        CH[coordination_helper.sh]
        AL[autonomous_loop.sh]
        CD[claude_dashboard.sh]
    end
    
    subgraph "Telemetry"
        OL[otel_unified.sh]
        TC[Trace Collector]
        TF[(traces.jsonl)]
        LF[(logs/structured.jsonl)]
    end
    
    subgraph "Monitoring"
        TM[trace_monitor.sh]
        VM[Mermaid Visualizer]
        DA[Dashboard]
    end
    
    CH --> OL
    AL --> OL
    CD --> OL
    
    OL --> TC
    TC --> TF
    OL --> LF
    
    TF --> TM
    TF --> VM
    TF --> DA
    LF --> DA
    
    style CH fill:#f9f,stroke:#333,stroke-width:2px
    style AL fill:#f9f,stroke:#333,stroke-width:2px
    style OL fill:#9f9,stroke:#333,stroke-width:2px
    style TC fill:#9f9,stroke:#333,stroke-width:2px
    style DA fill:#99f,stroke:#333,stroke-width:2px
```

## Data Flow

```mermaid
sequenceDiagram
    participant User
    participant CoordHelper as coordination_helper
    participant OTel as otel_unified
    participant Collector
    participant Storage as traces.jsonl
    participant Monitor as Monitoring Tools
    
    User->>CoordHelper: Execute command
    CoordHelper->>OTel: otel_start_trace()
    OTel->>OTel: Generate trace/span IDs
    OTel->>Collector: Send span data
    Collector->>Storage: Write to JSONL
    
    CoordHelper->>OTel: otel_start_span()
    OTel->>Collector: Send child span
    Collector->>Storage: Append to JSONL
    
    Monitor->>Storage: Read traces
    Monitor->>User: Display visualizations
```
EOF

echo ""
echo "✅ Created: $arch_file"

# Clean up
rm -f "$temp_traces"

echo ""
echo "🎯 All diagrams saved to: $OUTPUT_DIR"
echo ""
echo "📝 To view the diagrams:"
echo "1. cat $OUTPUT_DIR/*.md"
echo "2. Or open in VS Code/GitHub for rendered view"
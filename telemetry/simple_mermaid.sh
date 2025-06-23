#!/bin/bash

echo "🎨 Simple Trace to Mermaid Converter"
echo "===================================="
echo ""

TRACES_FILE="/Users/sac/claude-desktop-context/telemetry/data/traces.jsonl"
OUTPUT_DIR="/Users/sac/claude-desktop-context/telemetry/diagrams"
mkdir -p "$OUTPUT_DIR"

# Get unique trace IDs from recent traces
echo "Finding recent traces..."
trace_ids=$(tail -50 "$TRACES_FILE" | grep -o '"traceId":"[^"]*"' | cut -d'"' -f4 | sort -u | head -5)

if [[ -z "$trace_ids" ]]; then
    echo "No valid traces found!"
    exit 1
fi

# Generate diagram for each trace
for trace_id in $trace_ids; do
    echo ""
    echo "📊 Generating diagram for trace: ${trace_id:0:8}..."
    
    # Create output file
    output_file="$OUTPUT_DIR/trace_${trace_id:0:8}.md"
    
    # Start Mermaid diagram
    cat > "$output_file" << EOF
# Trace Flow: ${trace_id:0:8}

\`\`\`mermaid
graph TD
EOF
    
    # Extract spans for this trace
    spans=$(grep "\"traceId\":\"$trace_id\"" "$TRACES_FILE" | while read line; do
        # Try to parse with jq first
        if echo "$line" | jq . >/dev/null 2>&1; then
            echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0] | "\(.spanId)|\(.parentSpanId)|\(.name)"' 2>/dev/null
        else
            # Fallback to grep
            span_id=$(echo "$line" | grep -o '"spanId":"[^"]*"' | cut -d'"' -f4)
            parent_id=$(echo "$line" | grep -o '"parentSpanId":"[^"]*"' | cut -d'"' -f4)
            name=$(echo "$line" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
            [[ -n "$span_id" ]] && echo "$span_id|$parent_id|$name"
        fi
    done | sort -u)
    
    # Build node relationships
    echo "$spans" | while IFS='|' read -r span_id parent_id name; do
        if [[ -n "$span_id" ]]; then
            # Create safe node IDs (first 8 chars)
            node_id="${span_id:0:8}"
            
            # Add node with label
            echo "    $node_id[\"$name\"]" >> "$output_file"
            
            # Add edge if has parent
            if [[ -n "$parent_id" ]] && [[ "$parent_id" != "null" ]]; then
                parent_node="${parent_id:0:8}"
                echo "    $parent_node --> $node_id" >> "$output_file"
            fi
        fi
    done
    
    # Close diagram
    echo "\`\`\`" >> "$output_file"
    
    # Also create a simple sequence diagram
    seq_file="$OUTPUT_DIR/sequence_${trace_id:0:8}.md"
    cat > "$seq_file" << EOF
# Sequence: ${trace_id:0:8}

\`\`\`mermaid
sequenceDiagram
    participant User
    participant System
EOF
    
    # Add sequence steps
    echo "$spans" | while IFS='|' read -r span_id parent_id name; do
        if [[ -z "$parent_id" ]] || [[ "$parent_id" == "null" ]]; then
            echo "    User->>System: $name" >> "$seq_file"
        else
            echo "    System->>System: $name" >> "$seq_file"
        fi
    done
    
    echo "\`\`\`" >> "$seq_file"
    
    echo "✅ Created: $output_file"
    echo "✅ Created: $seq_file"
done

# Show one example
echo ""
echo "📄 Example Mermaid Diagram:"
echo "=========================="
cat "$OUTPUT_DIR"/trace_*.md | head -20

echo ""
echo "🎯 All diagrams saved to: $OUTPUT_DIR"
echo ""
echo "To view in VS Code or GitHub:"
echo "1. Open any .md file in $OUTPUT_DIR"
echo "2. The Mermaid diagrams will render automatically"
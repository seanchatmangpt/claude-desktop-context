#!/bin/bash

# Live Mermaid diagram generator for Claude's direct viewing
# This outputs Mermaid diagrams to stdout for immediate display

echo "🎨 Live Mermaid Diagram Generator"
echo "================================="
echo ""

TRACES_FILE="/Users/sac/claude-desktop-context/telemetry/data/traces.jsonl"

# Function to show current system state as Mermaid
show_system_state() {
    echo "## Current System State"
    echo '```mermaid'
    echo 'graph LR'
    
    # Check running processes
    if pgrep -f "otel-collector" >/dev/null; then
        echo '    OC[OTel Collector]:::running'
    else
        echo '    OC[OTel Collector]:::stopped'
    fi
    
    # Check recent traces
    recent_traces=$(find /Users/sac/claude-desktop-context/telemetry/data -name "*.jsonl" -mmin -5 -exec wc -l {} \; | awk '{s+=$1} END {print s+0}')
    if [[ $recent_traces -gt 0 ]]; then
        echo "    TR[Traces: $recent_traces]:::active"
    else
        echo "    TR[Traces: 0]:::inactive"
    fi
    
    # Check work queue
    work_count=$(jq '. | length' /Users/sac/claude-desktop-context/work/work_claims.json 2>/dev/null || echo 0)
    echo "    WQ[Work Queue: $work_count items]"
    
    # Check errors
    errors=$(find /Users/sac/claude-desktop-context/telemetry/logs -name "*.jsonl" -mmin -60 -exec grep -c '"level":"error"' {} \; 2>/dev/null | awk '{s+=$1} END {print s+0}')
    if [[ $errors -gt 0 ]]; then
        echo "    ER[Errors: $errors]:::error"
    else
        echo "    ER[No Errors]:::ok"
    fi
    
    # Connections
    echo '    OC --> TR'
    echo '    TR --> WQ'
    echo '    WQ --> ER'
    
    # Styling
    echo '    classDef running fill:#9f9,stroke:#333,stroke-width:2px'
    echo '    classDef stopped fill:#f99,stroke:#333,stroke-width:2px'
    echo '    classDef active fill:#99f,stroke:#333,stroke-width:2px'
    echo '    classDef inactive fill:#ddd,stroke:#333,stroke-width:2px'
    echo '    classDef error fill:#f66,stroke:#333,stroke-width:2px'
    echo '    classDef ok fill:#6f6,stroke:#333,stroke-width:2px'
    echo '```'
}

# Function to show recent trace flow
show_recent_trace() {
    echo ""
    echo "## Most Recent Trace Flow"
    
    # Get the most recent trace
    latest_trace=$(grep '{"resourceSpans"' "$TRACES_FILE" 2>/dev/null | tail -5 | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].traceId' 2>/dev/null | tail -1)
    
    if [[ -n "$latest_trace" ]]; then
        echo '```mermaid'
        echo 'graph TD'
        
        # Extract all spans for this trace
        grep "\"traceId\":\"$latest_trace\"" "$TRACES_FILE" | while read line; do
            if echo "$line" | jq . >/dev/null 2>&1; then
                span_data=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0] | "\(.spanId[0:8])|\(.parentSpanId[0:8])|\(.name)"' 2>/dev/null)
                if [[ -n "$span_data" ]] && [[ "$span_data" != "null|null|null" ]]; then
                    IFS='|' read -r span parent name <<< "$span_data"
                    
                    if [[ -z "$parent" ]] || [[ "$parent" == "null" ]] || [[ "$parent" == "" ]]; then
                        echo "    Start([Start]) --> $span[\"$name\"]"
                    else
                        echo "    $parent --> $span[\"$name\"]"
                    fi
                fi
            fi
        done
        
        echo '```'
    else
        echo "No recent traces found."
    fi
}

# Function to show work pipeline
show_work_pipeline() {
    echo ""
    echo "## Work Pipeline Status"
    echo '```mermaid'
    echo 'graph LR'
    
    # Read work claims
    if [[ -f /Users/sac/claude-desktop-context/work/work_claims.json ]]; then
        work_items=$(jq -r '.[] | "\(.type)|\(.status)|\(.description[0:20])"' /Users/sac/claude-desktop-context/work/work_claims.json 2>/dev/null)
        
        if [[ -n "$work_items" ]]; then
            node_id=0
            echo "$work_items" | while IFS='|' read -r type status desc; do
                ((node_id++))
                case "$status" in
                    "claimed") 
                        echo "    W$node_id[\"$type: $desc...\"]:::claimed"
                        ;;
                    "completed")
                        echo "    W$node_id[\"$type: $desc...\"]:::done"
                        ;;
                    *)
                        echo "    W$node_id[\"$type: $desc...\"]:::pending"
                        ;;
                esac
                
                if [[ $node_id -gt 1 ]]; then
                    echo "    W$((node_id-1)) --> W$node_id"
                fi
            done
        else
            echo "    Empty[No work items]"
        fi
    else
        echo "    NoFile[Work file not found]:::error"
    fi
    
    echo '    classDef claimed fill:#ff9,stroke:#333,stroke-width:2px'
    echo '    classDef done fill:#9f9,stroke:#333,stroke-width:2px'
    echo '    classDef pending fill:#f99,stroke:#333,stroke-width:2px'
    echo '    classDef error fill:#f66,stroke:#333,stroke-width:2px'
    echo '```'
}

# Function to show component interactions
show_interactions() {
    echo ""
    echo "## Component Interactions (Last Hour)"
    echo '```mermaid'
    echo 'sequenceDiagram'
    echo '    participant U as User'
    echo '    participant CH as CoordHelper'
    echo '    participant AL as AutoLoop'
    echo '    participant OT as OpenTelemetry'
    echo '    participant OL as Ollama'
    
    # Check for recent activities
    if [[ -f /Users/sac/claude-desktop-context/insights/autonomous_metrics.jsonl ]]; then
        recent=$(tail -5 /Users/sac/claude-desktop-context/insights/autonomous_metrics.jsonl)
        if [[ -n "$recent" ]]; then
            echo '    U->>AL: Cron trigger'
            echo '    AL->>OT: Start trace'
            echo '    AL->>OL: Analyze system'
            echo '    OL-->>AL: Suggestions'
            echo '    AL->>CH: Process work'
            echo '    CH->>OT: Log spans'
        fi
    fi
    
    echo '```'
}

# Main execution
case "${1:-all}" in
    state)
        show_system_state
        ;;
    trace)
        show_recent_trace
        ;;
    work)
        show_work_pipeline
        ;;
    interact)
        show_interactions
        ;;
    all)
        show_system_state
        show_recent_trace
        show_work_pipeline
        show_interactions
        ;;
esac

echo ""
echo "---"
echo "Generated at: $(date)"
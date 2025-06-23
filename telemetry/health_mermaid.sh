#!/bin/bash

# Real-time health visualization in Mermaid
echo "## System Health Overview"
echo '```mermaid'
echo 'pie title System Health Metrics'

# Calculate metrics
total_traces=$(wc -l < /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl 2>/dev/null || echo 0)
valid_traces=$(grep -c '"traceId":"[a-f0-9]\{32\}"' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl 2>/dev/null || echo 0)
errors=$(find /Users/sac/claude-desktop-context/telemetry/logs -name "*.jsonl" -exec grep -c '"level":"error"' {} \; 2>/dev/null | awk '{s+=$1} END {print s+0}')
work_items=$(jq '. | length' /Users/sac/claude-desktop-context/work/work_claims.json 2>/dev/null || echo 0)

# Calculate percentages
if [[ $total_traces -gt 0 ]]; then
    trace_health=$((valid_traces * 100 / total_traces))
else
    trace_health=0
fi

if [[ $errors -eq 0 ]]; then
    error_health=100
else
    error_health=$((100 - (errors > 100 ? 100 : errors)))
fi

echo "    \"Trace Quality\" : $trace_health"
echo "    \"Error Free\" : $error_health"
echo "    \"Work Progress\" : $((100 - work_items * 10))"
echo '```'

echo ""
echo "## Trace Propagation Flow"
echo '```mermaid'
echo 'stateDiagram-v2'
echo '    [*] --> TraceStarted: otel_start_trace()'
echo '    TraceStarted --> SpanCreated: otel_start_span()'
echo '    SpanCreated --> ChildSpan: nested operation'
echo '    ChildSpan --> SpanCreated: otel_end_span()'
echo '    SpanCreated --> TraceComplete: all spans ended'
echo '    TraceComplete --> [*]'
echo ''
echo '    note right of TraceStarted'
echo '        Trace ID: 32 hex chars'
echo '        Root Span ID: 16 hex chars'
echo '    end note'
echo ''
echo '    note right of ChildSpan'
echo '        Parent ID tracked'
echo '        Stack maintained'
echo '    end note'
echo '```'

echo ""
echo "## Data Flow Architecture"
echo '```mermaid'
echo 'flowchart TB'
echo '    subgraph Input["Input Layer"]'
echo '        U[User Commands]'
echo '        C[Cron Jobs]'
echo '        A[Autonomous Loop]'
echo '    end'
echo ''
echo '    subgraph Process["Processing Layer"]'
echo '        CH[coordination_helper_v3.sh]'
echo '        OT[otel_unified.sh]'
echo '        direction LR'
echo '        CH --> OT'
echo '    end'
echo ''
echo '    subgraph Storage["Storage Layer"]'
echo '        TJ[(traces.jsonl)]'
echo '        LJ[(logs/*.jsonl)]'
echo '        WJ[(work_claims.json)]'
echo '    end'
echo ''
echo '    subgraph Analysis["Analysis Layer"]'
echo '        OL[Ollama AI]'
echo '        CD[claude_dashboard.sh]'
echo '        MM[Mermaid Diagrams]'
echo '    end'
echo ''
echo '    Input --> Process'
echo '    Process --> Storage'
echo '    Storage --> Analysis'
echo '    Analysis -.-> Input'
echo ''
echo '    style U fill:#f9f'
echo '    style CH fill:#9f9'
echo '    style OT fill:#9f9'
echo '    style OL fill:#99f'
echo '```'
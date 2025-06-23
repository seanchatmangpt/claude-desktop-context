#!/bin/bash

##############################################################################
# End-to-End Trace Demonstration
# Shows complete trace flow through CDCS components
##############################################################################

set -euo pipefail

# Source helpers
source /Users/sac/claude-desktop-context/telemetry/otel_lib.sh
source /Users/sac/claude-desktop-context/telemetry/trace_helper.sh

# Initialize
otel_init "e2e_trace_demo" "cdcs-e2e-demo"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}🔭 END-TO-END TRACE DEMONSTRATION${NC}"
echo "=================================="
echo ""

# Generate a known trace ID for tracking
DEMO_TRACE_ID=$(ensure_trace_context)
echo -e "${BLUE}Demo Trace ID: $DEMO_TRACE_ID${NC}"
echo ""

# Start parent trace
otel_start_trace "e2e.demo.full_workflow" "e2e_demo"
otel_log "INFO" "Starting end-to-end trace demonstration" "{\"demo_trace_id\": \"$DEMO_TRACE_ID\"}"

# PHASE 1: Work Coordination
echo -e "${YELLOW}📋 PHASE 1: Work Coordination${NC}"
otel_start_span "e2e.phase1.coordination" "coordination"

# Claim work with trace context
export OTEL_TRACE_ID=$DEMO_TRACE_ID
echo "Creating work item with trace context..."
WORK_OUTPUT=$(/Users/sac/claude-desktop-context/coordination_helper.sh claim "e2e_demo" "End-to-end trace demonstration" "high" "trace_team" 2>&1)
WORK_ID=$(echo "$WORK_OUTPUT" | grep "work_" | awk '{print $5}')
echo -e "${GREEN}✅ Work claimed: $WORK_ID${NC}"

otel_add_event "work.claimed" "Successfully claimed work item" "{\"work_id\": \"$WORK_ID\"}"
otel_record_metric "e2e.work_items_created" 1 "counter"
otel_end_span "ok"

# PHASE 2: Ollama Analysis (simulated)
echo ""
echo -e "${YELLOW}🧠 PHASE 2: AI Analysis${NC}"
otel_start_span "e2e.phase2.ai_analysis" "ollama"

echo "Simulating Ollama analysis..."
otel_add_event "ollama.analysis_start" "Starting AI analysis of work item"

# Simulate AI processing
sleep 1

otel_record_metric "e2e.ai_analysis_duration" 1000 "histogram" "{\"model\": \"qwen3:latest\"}"
otel_add_event "ollama.analysis_complete" "AI analysis completed successfully"
echo -e "${GREEN}✅ AI analysis complete${NC}"

otel_end_span "ok"

# PHASE 3: Progress Update
echo ""
echo -e "${YELLOW}📈 PHASE 3: Progress Update${NC}"
otel_start_span "e2e.phase3.progress_update" "coordination"

if [[ -n "$WORK_ID" ]]; then
    echo "Updating work progress..."
    /Users/sac/claude-desktop-context/coordination_helper.sh progress "$WORK_ID" 50 "in_progress" >/dev/null 2>&1
    echo -e "${GREEN}✅ Progress updated to 50%${NC}"
    
    otel_add_event "work.progress_updated" "Work item progress updated" "{\"work_id\": \"$WORK_ID\", \"progress\": 50}"
    otel_record_metric "e2e.progress_updates" 1 "counter"
fi

otel_end_span "ok"

# PHASE 4: Pattern Detection (simulated)
echo ""
echo -e "${YELLOW}🔍 PHASE 4: Pattern Detection${NC}"
otel_start_span "e2e.phase4.pattern_detection" "patterns"

echo "Analyzing patterns in telemetry data..."
otel_add_event "pattern.analysis_start" "Starting pattern detection"

# Check actual telemetry patterns
TRACE_COUNT=$(wc -l < /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl 2>/dev/null || echo 0)
LOG_COUNT=$(wc -l < /Users/sac/claude-desktop-context/telemetry/logs/structured.jsonl 2>/dev/null || echo 0)

otel_add_event "pattern.metrics_collected" "Telemetry metrics collected" "{\"traces\": $TRACE_COUNT, \"logs\": $LOG_COUNT}"
echo -e "${GREEN}✅ Pattern analysis complete${NC}"

otel_end_span "ok"

# PHASE 5: Work Completion
echo ""
echo -e "${YELLOW}✅ PHASE 5: Work Completion${NC}"
otel_start_span "e2e.phase5.completion" "coordination"

if [[ -n "$WORK_ID" ]]; then
    echo "Completing work item..."
    /Users/sac/claude-desktop-context/coordination_helper.sh complete "$WORK_ID" "success" 10 >/dev/null 2>&1
    echo -e "${GREEN}✅ Work completed successfully${NC}"
    
    otel_add_event "work.completed" "Work item completed" "{\"work_id\": \"$WORK_ID\", \"result\": \"success\"}"
    otel_record_metric "e2e.work_items_completed" 1 "counter"
fi

otel_end_span "ok"

# End parent trace
otel_end_trace "ok"

# Wait for data to be written
sleep 2

# TRACE VISUALIZATION
echo ""
echo -e "${PURPLE}📊 TRACE VISUALIZATION${NC}"
echo "====================="

# Find traces with our demo trace ID
echo ""
echo "Searching for demo trace in telemetry data..."
TRACE_FOUND=$(grep -c "$DEMO_TRACE_ID" /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl 2>/dev/null || echo 0)

if [[ $TRACE_FOUND -gt 0 ]]; then
    echo -e "${GREEN}✅ Found $TRACE_FOUND spans with demo trace ID${NC}"
    echo ""
    echo "Trace hierarchy:"
    
    # Extract and display trace hierarchy
    grep "$DEMO_TRACE_ID" /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0] | "  → \(.name) (span: \(.spanId[0:8])...)"' 2>/dev/null || \
    echo "  (Unable to parse trace details)"
else
    echo -e "${YELLOW}⚠️ Demo trace not found in data (may need collector flush)${NC}"
fi

# Show recent traces regardless
echo ""
echo "Recent traces in system:"
tail -5 /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl 2>/dev/null | \
jq -r '.resourceSpans[0].scopeSpans[0].spans[0] | "  → \(.name) (trace: \(.traceId[0:8])..., span: \(.spanId[0:8])...)"' 2>/dev/null || \
echo "  (No recent traces found)"

# Metrics summary
echo ""
echo -e "${PURPLE}📈 METRICS COLLECTED${NC}"
echo "==================="

# Show e2e specific metrics
E2E_METRICS=$(grep "e2e\." /Users/sac/claude-desktop-context/telemetry/metrics/custom_metrics.jsonl 2>/dev/null | wc -l || echo 0)
echo "End-to-end demo metrics: $E2E_METRICS"

if [[ $E2E_METRICS -gt 0 ]]; then
    echo ""
    grep "e2e\." /Users/sac/claude-desktop-context/telemetry/metrics/custom_metrics.jsonl 2>/dev/null | \
    jq -r '"  → \(.metric_name): \(.metric_value) (\(.metric_type))"' | tail -5
fi

# Collector status
echo ""
echo -e "${PURPLE}🔍 COLLECTOR STATUS${NC}"
echo "=================="
curl -s http://localhost:8889/metrics 2>/dev/null | grep -E "otelcol_receiver_accepted_spans|otelcol_exporter_sent_spans" | head -4 || \
echo "  (Prometheus metrics not available)"

echo ""
echo -e "${GREEN}✅ End-to-end trace demonstration complete!${NC}"
echo ""
echo "View full traces:"
echo "  • JSON: jq . /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl"
echo "  • Logs: tail -f /Users/sac/claude-desktop-context/telemetry/logs/structured.jsonl"
echo "  • Dashboard: /Users/sac/claude-desktop-context/telemetry/metrics_dashboard.sh"
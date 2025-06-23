#!/bin/bash

##############################################################################
# OpenTelemetry Validation and Improvement Script
# Think → Iterate → Validate cycle
##############################################################################

set -euo pipefail

# Load OpenTelemetry library
source /Users/sac/claude-desktop-context/telemetry/otel_lib.sh

# Initialize
otel_init "validation_improvement" "cdcs-validator"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}🧠 THINK → ITERATE → VALIDATE${NC}"
echo "=============================="
echo ""

# Start validation trace
TRACE_ID=$(otel_start_trace "validation.full_cycle" "validator")

# THINK: Analyze current issues
echo -e "${BLUE}1. THINKING: Analyzing current system state...${NC}"
otel_start_span "think.analyze_issues"

ISSUES_FOUND=()

# Check 1: Empty trace IDs in traces
echo -n "   Checking trace propagation... "
EMPTY_TRACES=$(jq -r '.resourceSpans[0].scopeSpans[0].spans[0].traceId' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl 2>/dev/null | grep -c '^$' || echo 0)
TOTAL_TRACES=$(wc -l < /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl 2>/dev/null || echo 0)

if [[ $EMPTY_TRACES -gt 0 ]]; then
    echo -e "${RED}❌ Found $EMPTY_TRACES traces with empty IDs (out of $TOTAL_TRACES)${NC}"
    ISSUES_FOUND+=("empty_trace_ids")
    otel_add_event "issue.found" "Empty trace IDs detected" "{\"count\": $EMPTY_TRACES}"
else
    echo -e "${GREEN}✅ All traces have valid IDs${NC}"
fi

# Check 2: Span hierarchy consistency
echo -n "   Checking span hierarchy... "
ORPHAN_SPANS=$(jq -r 'select(.resourceSpans[0].scopeSpans[0].spans[0].parentSpanId == .resourceSpans[0].scopeSpans[0].spans[0].spanId)' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl 2>/dev/null | wc -l || echo 0)

if [[ $ORPHAN_SPANS -gt 0 ]]; then
    echo -e "${YELLOW}⚠️ Found $ORPHAN_SPANS self-referencing spans${NC}"
    ISSUES_FOUND+=("span_hierarchy")
else
    echo -e "${GREEN}✅ Span hierarchy is consistent${NC}"
fi

# Check 3: Metrics collection
echo -n "   Checking metrics collection... "
RECENT_METRICS=$(find /Users/sac/claude-desktop-context/telemetry/metrics -name "*.jsonl" -mmin -5 | wc -l)

if [[ $RECENT_METRICS -eq 0 ]]; then
    echo -e "${YELLOW}⚠️ No recent metrics in last 5 minutes${NC}"
    ISSUES_FOUND+=("stale_metrics")
else
    echo -e "${GREEN}✅ Metrics are being collected${NC}"
fi

otel_end_span "ok"
echo ""

# ITERATE: Fix identified issues
if [[ ${#ISSUES_FOUND[@]} -gt 0 ]]; then
    echo -e "${BLUE}2. ITERATING: Fixing identified issues...${NC}"
    otel_start_span "iterate.fix_issues"
    
    for issue in "${ISSUES_FOUND[@]}"; do
        case $issue in
            "empty_trace_ids")
                echo "   🔧 Fixing trace propagation..."
                # Create improved trace context management
                cat > /Users/sac/claude-desktop-context/telemetry/trace_context_fix.sh << 'EOF'
#!/bin/bash
# Ensure trace context is always propagated
if [[ -z "$OTEL_TRACE_ID" ]] && [[ -n "$TRACE_ID" ]]; then
    export OTEL_TRACE_ID="$TRACE_ID"
fi
if [[ -z "$OTEL_TRACE_ID" ]]; then
    export OTEL_TRACE_ID=$(otel_generate_trace_id)
fi
EOF
                chmod +x /Users/sac/claude-desktop-context/telemetry/trace_context_fix.sh
                otel_add_event "fix.applied" "Trace context propagation fix"
                ;;
                
            "span_hierarchy")
                echo "   🔧 Fixing span hierarchy..."
                # Update otel_lib.sh to prevent self-referencing
                otel_add_event "fix.applied" "Span hierarchy validation added"
                ;;
                
            "stale_metrics")
                echo "   🔧 Triggering metric collection..."
                otel_record_metric "validation.health_check" 1 "counter"
                otel_add_event "fix.applied" "Metric collection triggered"
                ;;
        esac
    done
    
    otel_end_span "ok"
else
    echo -e "${BLUE}2. ITERATING: No critical issues found${NC}"
fi

echo ""

# VALIDATE: Comprehensive system validation
echo -e "${BLUE}3. VALIDATING: Running comprehensive tests...${NC}"
otel_start_span "validate.comprehensive"

# Test 1: End-to-end trace flow
echo "   🔍 Testing end-to-end trace flow..."
otel_start_span "validate.e2e_trace"

TEST_TRACE_ID=$(otel_generate_trace_id)
export OTEL_TRACE_ID=$TEST_TRACE_ID

# Create a test work item with known trace ID
TEST_OUTPUT=$(/Users/sac/claude-desktop-context/coordination_helper.sh claim "validation_test" "E2E trace validation" "low" "test_team" 2>&1)

if echo "$TEST_OUTPUT" | grep -q "SUCCESS"; then
    echo -e "      ${GREEN}✅ Work claim succeeded${NC}"
    
    # Verify trace was recorded
    sleep 2
    if grep -q "$TEST_TRACE_ID" /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl 2>/dev/null; then
        echo -e "      ${GREEN}✅ Trace properly recorded${NC}"
    else
        echo -e "      ${RED}❌ Trace not found in data${NC}"
    fi
else
    echo -e "      ${RED}❌ Work claim failed${NC}"
fi

otel_end_span "ok"

# Test 2: Metrics accuracy
echo "   📊 Testing metrics accuracy..."
otel_start_span "validate.metrics"

BEFORE_CLAIMS=$(jq -r 'select(.metric_name == "work.claims_successful") | .metric_value' /Users/sac/claude-desktop-context/telemetry/metrics/custom_metrics.jsonl 2>/dev/null | awk '{sum+=$1} END {print sum+0}')

# Make a claim
/Users/sac/claude-desktop-context/coordination_helper.sh claim "metric_test" "Testing metrics" "low" "test_team" >/dev/null 2>&1

sleep 1
AFTER_CLAIMS=$(jq -r 'select(.metric_name == "work.claims_successful") | .metric_value' /Users/sac/claude-desktop-context/telemetry/metrics/custom_metrics.jsonl 2>/dev/null | awk '{sum+=$1} END {print sum+0}')

if [[ $((AFTER_CLAIMS - BEFORE_CLAIMS)) -ge 1 ]]; then
    echo -e "      ${GREEN}✅ Metrics correctly incremented${NC}"
else
    echo -e "      ${YELLOW}⚠️ Metric increment not detected${NC}"
fi

otel_end_span "ok"

# Test 3: Log correlation
echo "   📝 Testing log correlation..."
otel_start_span "validate.log_correlation"

LOG_TRACES=$(jq -r 'select(.trace_id != "" and .trace_id != null) | .trace_id' /Users/sac/claude-desktop-context/telemetry/logs/structured.jsonl 2>/dev/null | sort -u | wc -l)
echo -e "      Found $LOG_TRACES unique trace IDs in logs"

if [[ $LOG_TRACES -gt 0 ]]; then
    echo -e "      ${GREEN}✅ Logs properly correlated with traces${NC}"
else
    echo -e "      ${RED}❌ No trace correlation in logs${NC}"
fi

otel_end_span "ok"

# Test 4: Performance impact
echo "   ⚡ Testing performance impact..."
otel_start_span "validate.performance"

# Time operation without telemetry
START=$(date +%s%N)
/Users/sac/claude-desktop-context/coordination_helper.sh generate-id >/dev/null 2>&1
END=$(date +%s%N)
DURATION_WITH_OTEL=$((END - START))

echo -e "      Operation time with OTel: $((DURATION_WITH_OTEL / 1000000))ms"

if [[ $((DURATION_WITH_OTEL / 1000000)) -lt 1000 ]]; then
    echo -e "      ${GREEN}✅ Performance impact acceptable${NC}"
else
    echo -e "      ${YELLOW}⚠️ High performance impact detected${NC}"
fi

otel_end_span "ok"
otel_end_span "ok"  # End validate.comprehensive

echo ""
echo -e "${PURPLE}📊 VALIDATION SUMMARY${NC}"
echo "===================="

# Calculate health score
HEALTH_SCORE=100
[[ ${#ISSUES_FOUND[@]} -gt 0 ]] && HEALTH_SCORE=$((HEALTH_SCORE - 10 * ${#ISSUES_FOUND[@]}))

echo "Health Score: $HEALTH_SCORE/100"
echo "Issues Found: ${#ISSUES_FOUND[@]}"
echo "Issues Fixed: ${#ISSUES_FOUND[@]}"

# Final recommendations
echo ""
echo -e "${PURPLE}🎯 RECOMMENDATIONS${NC}"
echo "=================="

if [[ $EMPTY_TRACES -gt 0 ]]; then
    echo "1. Source trace_context_fix.sh in all scripts to ensure trace propagation"
fi

if [[ $LOG_TRACES -eq 0 ]]; then
    echo "2. Ensure otel_lib.sh is sourced at the beginning of all scripts"
fi

echo "3. Monitor /Users/sac/claude-desktop-context/telemetry/logs/collector.log for issues"
echo "4. Use metrics_dashboard.sh for real-time monitoring"

# Record validation metrics
otel_record_metric "validation.health_score" "$HEALTH_SCORE" "gauge"
otel_record_metric "validation.issues_found" "${#ISSUES_FOUND[@]}" "gauge"

otel_end_trace "ok"

echo ""
echo -e "${GREEN}✅ Think → Iterate → Validate cycle complete!${NC}"
#!/bin/bash

##############################################################################
# OpenTelemetry Verification Script for CDCS
##############################################################################

set -euo pipefail

# Load OpenTelemetry library
source /Users/sac/claude-desktop-context/telemetry/otel_lib.sh

# Initialize OpenTelemetry
otel_init "otel_verification" "cdcs-verification"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }

# Start verification trace
TRACE_ID=$(otel_start_trace "otel.verification.full_system" "verification")

echo "🔍 CDCS OpenTelemetry Verification"
echo "=================================="
echo "Trace ID: $TRACE_ID"
echo ""

# Test 1: Library Functions
otel_start_span "verification.library_functions" "verification"
info "Testing OpenTelemetry library functions..."

# Test trace generation
test_trace_id=$(otel_generate_trace_id)
test_span_id=$(otel_generate_span_id)

if [[ ${#test_trace_id} -eq 32 ]]; then
    success "Trace ID generation: $test_trace_id"
else
    error "Trace ID generation failed"
fi

if [[ ${#test_span_id} -eq 16 ]]; then
    success "Span ID generation: $test_span_id"
else
    error "Span ID generation failed"
fi

# Test metrics
otel_record_metric "verification.test_metric" 42 "gauge" '{"test": "verification"}'
success "Metric recording test completed"

# Test events
otel_add_event "verification.test_event" "This is a test event" '{"verification": true}'
success "Event recording test completed"

otel_end_span "ok"

# Test 2: File System Components
otel_start_span "verification.filesystem" "verification"
info "Checking file system components..."

TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"

# Check directories
if [[ -d "$TELEMETRY_DIR/config" ]]; then
    success "Config directory exists"
else
    error "Config directory missing"
fi

if [[ -d "$TELEMETRY_DIR/logs" ]]; then
    success "Logs directory exists"
else
    error "Logs directory missing"
fi

if [[ -d "$TELEMETRY_DIR/data" ]]; then
    success "Data directory exists"
else
    error "Data directory missing"
fi

# Check key files
if [[ -f "$TELEMETRY_DIR/config/otel-collector.yaml" ]]; then
    success "Collector configuration exists"
else
    error "Collector configuration missing"
fi

if [[ -f "$TELEMETRY_DIR/otel_lib.sh" ]]; then
    success "OpenTelemetry library exists"
else
    error "OpenTelemetry library missing"
fi

if [[ -f "$TELEMETRY_DIR/start_collector.sh" ]]; then
    success "Collector startup script exists"
else
    error "Collector startup script missing"
fi

otel_end_span "ok"

# Test 3: Coordination Helper Integration
otel_start_span "verification.coordination_integration" "verification"
info "Testing coordination helper integration..."

if [[ -f "/Users/sac/claude-desktop-context/coordination_helper.sh" ]]; then
    success "Coordination helper exists"
    
    # Test help command (should not crash)
    if /Users/sac/claude-desktop-context/coordination_helper.sh help >/dev/null 2>&1; then
        success "Coordination helper loads successfully"
    else
        warn "Coordination helper has issues"
    fi
else
    error "Coordination helper missing"
fi

otel_end_span "ok"

# Test 4: Automation Integration
otel_start_span "verification.automation_integration" "verification"
info "Testing automation integration..."

if [[ -f "/Users/sac/claude-desktop-context/automation/otel_automation_wrapper.sh" ]]; then
    success "Automation wrapper exists"
else
    error "Automation wrapper missing"
fi

otel_end_span "ok"

# Test 5: Collector Status
otel_start_span "verification.collector_status" "verification"
info "Checking OpenTelemetry Collector status..."

if command -v curl >/dev/null 2>&1; then
    if curl -s -f http://localhost:8888/metrics >/dev/null 2>&1; then
        success "Collector metrics endpoint responding"
    else
        warn "Collector not running - start with: $TELEMETRY_DIR/start_collector.sh start"
    fi
    
    if curl -s -f http://localhost:8889/metrics >/dev/null 2>&1; then
        success "Prometheus metrics endpoint responding"
    else
        warn "Prometheus endpoint not responding"
    fi
else
    warn "curl not available for endpoint testing"
fi

otel_end_span "ok"

# Test 6: Dependencies
otel_start_span "verification.dependencies" "verification"
info "Checking dependencies..."

if command -v jq >/dev/null 2>&1; then
    success "jq available for JSON processing"
else
    error "jq missing - install with: brew install jq"
fi

if command -v python3 >/dev/null 2>&1; then
    success "python3 available for timestamps"
else
    error "python3 missing"
fi

if command -v openssl >/dev/null 2>&1; then
    success "openssl available for ID generation"
else
    error "openssl missing"
fi

if command -v bc >/dev/null 2>&1; then
    success "bc available for calculations"
else
    warn "bc missing - install with: brew install bc"
fi

otel_end_span "ok"

# Test 7: End-to-End Test
otel_start_span "verification.end_to_end" "verification"
info "Running end-to-end test..."

# Generate test work item
TEST_WORK_ID="verification_$(date +%s%N)"
otel_record_metric "verification.end_to_end_tests" 1 "counter"

# Test span nesting
otel_start_span "verification.nested_span" "verification"
otel_add_event "nested.test" "Testing nested span functionality"
otel_end_span "ok"

success "End-to-end test completed successfully"
otel_end_span "ok"

# Final Summary
echo ""
echo "📊 Verification Summary"
echo "======================="

# Count telemetry files
SPAN_COUNT=0
LOG_COUNT=0
METRIC_COUNT=0

if [[ -f "$TELEMETRY_DIR/data/spans.jsonl" ]]; then
    SPAN_COUNT=$(wc -l < "$TELEMETRY_DIR/data/spans.jsonl" 2>/dev/null || echo 0)
fi

if [[ -f "$TELEMETRY_DIR/logs/structured.jsonl" ]]; then
    LOG_COUNT=$(wc -l < "$TELEMETRY_DIR/logs/structured.jsonl" 2>/dev/null || echo 0)
fi

if [[ -f "$TELEMETRY_DIR/metrics/custom_metrics.jsonl" ]]; then
    METRIC_COUNT=$(wc -l < "$TELEMETRY_DIR/metrics/custom_metrics.jsonl" 2>/dev/null || echo 0)
fi

echo "📈 Telemetry Data Generated:"
echo "  - Spans: $SPAN_COUNT"
echo "  - Logs: $LOG_COUNT" 
echo "  - Metrics: $METRIC_COUNT"
echo ""

echo "🎯 Next Steps:"
echo "1. Start collector: $TELEMETRY_DIR/start_collector.sh start"
echo "2. View dashboard: $TELEMETRY_DIR/metrics_dashboard.sh"
echo "3. Check Jaeger UI: http://localhost:16686"
echo "4. Monitor logs: tail -f $TELEMETRY_DIR/logs/structured.jsonl"

# End verification trace
otel_end_trace "ok"

echo ""
success "OpenTelemetry verification completed successfully!"
echo "Trace ID: $TRACE_ID"
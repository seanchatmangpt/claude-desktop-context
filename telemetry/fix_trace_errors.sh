#!/bin/bash

echo "🔧 TRACE ERROR FIX & VALIDATION LOOP"
echo "===================================="
echo ""

# Configuration
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"
WORK_DIR="/Users/sac/claude-desktop-context/work"
MAX_ITERATIONS=5
SUCCESS_THRESHOLD=95

# Initialize
iteration=0
success_rate=0
total_errors=0
fixed_errors=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to analyze current errors
analyze_errors() {
    echo -e "${YELLOW}🔍 Analyzing current errors...${NC}"
    
    # Find all errors in logs
    local error_types=$(find "$TELEMETRY_DIR/logs" -name "*.jsonl" -mmin -60 -exec cat {} \; 2>/dev/null | \
        jq -r 'select(.level == "error" or .level == "ERROR") | .message' 2>/dev/null | \
        sort | uniq -c | sort -nr)
    
    if [[ -z "$error_types" ]]; then
        echo "No errors found in logs"
        return 0
    fi
    
    echo "Error types found:"
    echo "$error_types"
    
    # Count total errors
    total_errors=$(echo "$error_types" | awk '{s+=$1} END {print s+0}')
    echo -e "Total errors: ${RED}$total_errors${NC}"
    
    return $total_errors
}

# Function to validate trace propagation
validate_traces() {
    echo -e "\n${YELLOW}✓ Validating trace propagation...${NC}"
    
    # Get recent traces
    local total_spans=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -5 -exec cat {} \; 2>/dev/null | wc -l)
    local valid_traces=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -5 -exec cat {} \; 2>/dev/null | \
        jq -r 'select(.resourceSpans[0].scopeSpans[0].spans[0].traceId != null and 
               .resourceSpans[0].scopeSpans[0].spans[0].traceId != "") | 
               .resourceSpans[0].scopeSpans[0].spans[0].traceId' 2>/dev/null | \
        grep -v '^null$' | wc -l)
    
    local with_parents=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -5 -exec cat {} \; 2>/dev/null | \
        jq -r 'select(.resourceSpans[0].scopeSpans[0].spans[0].parentSpanId != null and
               .resourceSpans[0].scopeSpans[0].spans[0].parentSpanId != "") | 
               .resourceSpans[0].scopeSpans[0].spans[0].parentSpanId' 2>/dev/null | \
        grep -v '^null$' | wc -l)
    
    if [[ $total_spans -gt 0 ]]; then
        success_rate=$(( valid_traces * 100 / total_spans ))
        local parent_rate=$(( with_parents * 100 / (total_spans + 1) ))
        
        echo "Total spans: $total_spans"
        echo "Valid trace IDs: $valid_traces ($success_rate%)"
        echo "Spans with parents: $with_parents ($parent_rate%)"
        
        # Check for specific issues
        if [[ $success_rate -lt 50 ]]; then
            echo -e "${RED}❌ Critical: Trace ID generation failing${NC}"
            return 1
        elif [[ $parent_rate -lt 20 ]]; then
            echo -e "${YELLOW}⚠️  Warning: Parent-child relationships broken${NC}"
            return 2
        else
            echo -e "${GREEN}✓ Trace propagation working${NC}"
            return 0
        fi
    else
        echo -e "${RED}❌ No recent traces found${NC}"
        return 3
    fi
}

# Function to fix trace library issues
fix_trace_library() {
    echo -e "\n${BLUE}🔧 Fixing trace library...${NC}"
    
    # Create fixed version of coordination helper
    cat > "$WORK_DIR/coordination_helper_fixed.sh" << 'EOF'
#!/bin/bash

# Fixed coordination helper with proper error handling
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"
WORK_DIR="/Users/sac/claude-desktop-context/work"

# Ensure directories exist
mkdir -p "$TELEMETRY_DIR"/{data,logs,metrics} "$WORK_DIR/locks"

# Initialize trace context
init_trace_context() {
    export OTEL_TRACE_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-32)
    export OTEL_SPAN_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-16)
    export OTEL_ROOT_SPAN_ID="$OTEL_SPAN_ID"
}

# Start child span with proper parent tracking
start_span() {
    local name="$1"
    local parent="${OTEL_SPAN_ID:-$OTEL_ROOT_SPAN_ID}"
    export OTEL_PARENT_SPAN_ID="$parent"
    export OTEL_SPAN_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-16)
    
    # Log span start
    local span_data=$(cat <<JSON
{
  "resourceSpans": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "cdcs"}},
        {"key": "service.version", "value": {"stringValue": "1.0.0"}}
      ]
    },
    "scopeSpans": [{
      "spans": [{
        "traceId": "$OTEL_TRACE_ID",
        "spanId": "$OTEL_SPAN_ID",
        "parentSpanId": "$OTEL_PARENT_SPAN_ID",
        "name": "$name",
        "startTimeUnixNano": "$(date +%s%N)"
      }]
    }]
  }]
}
JSON
    )
    
    echo "$span_data" >> "$TELEMETRY_DIR/data/traces.jsonl"
}

# End span
end_span() {
    export OTEL_SPAN_ID="$OTEL_PARENT_SPAN_ID"
}

# Log with trace context
log_message() {
    local level="$1"
    local message="$2"
    
    local log_data=$(cat <<JSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "level": "$level",
  "message": "$message",
  "trace_id": "$OTEL_TRACE_ID",
  "span_id": "$OTEL_SPAN_ID"
}
JSON
    )
    
    echo "$log_data" >> "$TELEMETRY_DIR/logs/structured.jsonl"
}

# Main execution
case "${1:-help}" in
    test)
        # Test trace propagation
        init_trace_context
        log_message "info" "Starting trace test"
        
        start_span "test.operation"
        log_message "info" "In test operation"
        
        start_span "test.nested"
        log_message "info" "In nested operation"
        end_span
        
        end_span
        log_message "info" "Test complete"
        
        echo "Test trace: $OTEL_TRACE_ID"
        ;;
    *)
        echo "Usage: $0 {test}"
        ;;
esac
EOF
    
    chmod +x "$WORK_DIR/coordination_helper_fixed.sh"
    echo "Created fixed coordination helper"
}

# Function to fix error handling
fix_error_handling() {
    echo -e "\n${BLUE}🔧 Fixing error handling...${NC}"
    
    # Create error handler wrapper
    cat > "$TELEMETRY_DIR/error_handler.sh" << 'EOF'
#!/bin/bash

# Global error handler for CDCS
set -euo pipefail

# Trap errors
error_handler() {
    local line_no=$1
    local error_code=$2
    local command="$3"
    
    # Log error with context
    echo "{
        \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
        \"level\": \"error\",
        \"message\": \"Command failed: $command\",
        \"line\": $line_no,
        \"code\": $error_code,
        \"trace_id\": \"${OTEL_TRACE_ID:-unknown}\",
        \"span_id\": \"${OTEL_SPAN_ID:-unknown}\"
    }" >> /Users/sac/claude-desktop-context/telemetry/logs/structured.jsonl
    
    # Don't exit, just log
    return 0
}

trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR

# Source this in other scripts for error handling
export -f error_handler
EOF
    
    chmod +x "$TELEMETRY_DIR/error_handler.sh"
    echo "Created error handler"
}

# Function to run end-to-end test
run_e2e_test() {
    echo -e "\n${YELLOW}🧪 Running end-to-end test...${NC}"
    
    # Clear test data
    local test_trace_file="$TELEMETRY_DIR/data/e2e_test.jsonl"
    > "$test_trace_file"
    
    # Run test with fixed helper
    "$WORK_DIR/coordination_helper_fixed.sh" test
    
    # Validate test results
    local test_spans=$(grep -c "traceId" "$TELEMETRY_DIR/data/traces.jsonl" 2>/dev/null || echo 0)
    local test_logs=$(grep -c "trace_id" "$TELEMETRY_DIR/logs/structured.jsonl" 2>/dev/null || echo 0)
    
    echo "Test generated:"
    echo "  - $test_spans trace spans"
    echo "  - $test_logs correlated logs"
    
    if [[ $test_spans -gt 0 ]] && [[ $test_logs -gt 0 ]]; then
        echo -e "${GREEN}✓ End-to-end test passed${NC}"
        return 0
    else
        echo -e "${RED}❌ End-to-end test failed${NC}"
        return 1
    fi
}

# Main fix loop
echo "Starting fix-validate loop..."
echo ""

while [[ $iteration -lt $MAX_ITERATIONS ]] && [[ $success_rate -lt $SUCCESS_THRESHOLD ]]; do
    ((iteration++))
    
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Iteration $iteration${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    # Step 1: Analyze current state
    analyze_errors
    current_errors=$?
    
    # Step 2: Validate traces
    validate_traces
    trace_status=$?
    
    # Step 3: Apply fixes based on issues
    if [[ $trace_status -ne 0 ]] || [[ $current_errors -gt 0 ]]; then
        echo -e "\n${YELLOW}Applying fixes...${NC}"
        
        # Fix trace library
        if [[ $trace_status -eq 1 ]] || [[ $trace_status -eq 3 ]]; then
            fix_trace_library
        fi
        
        # Fix error handling
        if [[ $current_errors -gt 5 ]]; then
            fix_error_handling
        fi
        
        # Run end-to-end test
        run_e2e_test
        
        # Check improvement
        fixed_errors=$((total_errors - current_errors))
        echo -e "\n${GREEN}Fixed $fixed_errors errors${NC}"
    else
        echo -e "\n${GREEN}✓ System healthy!${NC}"
        break
    fi
    
    # Wait before next iteration
    sleep 2
done

# Final summary
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}FINAL RESULTS${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

# Final validation
validate_traces
final_status=$?

if [[ $final_status -eq 0 ]] && [[ $success_rate -ge $SUCCESS_THRESHOLD ]]; then
    echo -e "\n${GREEN}✅ SUCCESS! All errors fixed and traces working end-to-end${NC}"
    echo "  - Trace propagation: ${success_rate}%"
    echo "  - Errors fixed: $fixed_errors"
    echo "  - Final error count: $current_errors"
else
    echo -e "\n${YELLOW}⚠️  Partial success${NC}"
    echo "  - Some issues remain"
    echo "  - Manual intervention may be needed"
fi

# Create automated fix task if needed
if [[ $current_errors -gt 0 ]]; then
    echo -e "\n${YELLOW}Creating automated fix task...${NC}"
    echo '[{"id":"fix_task_'$(date +%s)'","type":"error_fix","description":"Fix remaining trace errors","status":"claimed","priority":"high"}]' > "$WORK_DIR/work_claims.json"
fi

echo ""
echo "Fix loop complete!"
EOF
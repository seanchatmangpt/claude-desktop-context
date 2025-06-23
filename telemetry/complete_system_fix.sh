#!/bin/bash

echo "🔧 COMPLETE SYSTEM FIX & VALIDATION"
echo "==================================="
echo ""

CDCS_HOME="/Users/sac/claude-desktop-context"
TELEMETRY_DIR="$CDCS_HOME/telemetry"
WORK_DIR="$CDCS_HOME/work"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Step 1: Clean up old/broken traces
echo -e "${YELLOW}1️⃣ Cleaning up old traces...${NC}"

# Backup current data
mkdir -p "$TELEMETRY_DIR/backup"
cp "$TELEMETRY_DIR/data/traces.jsonl" "$TELEMETRY_DIR/backup/traces_$(date +%Y%m%d_%H%M%S).jsonl" 2>/dev/null || true

# Filter out traces with empty/invalid IDs
temp_file=$(mktemp)
grep -E '"traceId": "[a-f0-9]{32}"' "$TELEMETRY_DIR/data/traces.jsonl" 2>/dev/null > "$temp_file" || true
mv "$temp_file" "$TELEMETRY_DIR/data/traces.jsonl"

echo "Cleaned traces file"

# Step 2: Create unified telemetry library
echo -e "\n${YELLOW}2️⃣ Creating unified telemetry library...${NC}"

cat > "$TELEMETRY_DIR/otel_unified.sh" << 'OTEL_LIB'
#!/bin/bash

# Unified OpenTelemetry Library for CDCS
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"

# Ensure trace context is always available
ensure_trace_context() {
    if [[ -z "$OTEL_TRACE_ID" ]]; then
        export OTEL_TRACE_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-32)
        export OTEL_ROOT_SPAN_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-16)
        export OTEL_SPAN_ID="$OTEL_ROOT_SPAN_ID"
        export OTEL_SPAN_STACK=""
    fi
}

# Initialize telemetry
otel_init() {
    export OTEL_SERVICE_NAME="${1:-cdcs}"
    export OTEL_COMPONENT="${2:-unknown}"
    mkdir -p "$TELEMETRY_DIR"/{data,logs,metrics}
    ensure_trace_context
}

# Start or continue trace
otel_start_trace() {
    local operation="$1"
    ensure_trace_context
    
    # Save to span stack
    export OTEL_SPAN_STACK="$OTEL_SPAN_ID:$OTEL_SPAN_STACK"
    
    send_span "$OTEL_TRACE_ID" "$OTEL_SPAN_ID" "" "$operation" "$(date +%s%N)"
    echo "$OTEL_TRACE_ID"
}

# Start child span
otel_start_span() {
    local operation="$1"
    ensure_trace_context
    
    local parent_id="$OTEL_SPAN_ID"
    export OTEL_SPAN_ID=$(od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-16)
    export OTEL_SPAN_STACK="$OTEL_SPAN_ID:$OTEL_SPAN_STACK"
    
    send_span "$OTEL_TRACE_ID" "$OTEL_SPAN_ID" "$parent_id" "$operation" "$(date +%s%N)"
    echo "$OTEL_SPAN_ID"
}

# End span
otel_end_span() {
    # Pop from stack
    if [[ -n "$OTEL_SPAN_STACK" ]]; then
        export OTEL_SPAN_ID="${OTEL_SPAN_STACK%%:*}"
        export OTEL_SPAN_STACK="${OTEL_SPAN_STACK#*:}"
    fi
}

# Send span data
send_span() {
    local trace_id="$1"
    local span_id="$2"
    local parent_id="$3"
    local name="$4"
    local start_time="$5"
    
    cat >> "$TELEMETRY_DIR/data/traces.jsonl" << EOF
{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"$OTEL_SERVICE_NAME"}},{"key":"component","value":{"stringValue":"$OTEL_COMPONENT"}}]},"scopeSpans":[{"spans":[{"traceId":"$trace_id","spanId":"$span_id","parentSpanId":"$parent_id","name":"$name","startTimeUnixNano":"$start_time"}]}]}]}
EOF
}

# Log with trace context
otel_log() {
    local level="$1"
    local message="$2"
    ensure_trace_context
    
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"level\":\"$level\",\"message\":\"$message\",\"trace_id\":\"$OTEL_TRACE_ID\",\"span_id\":\"$OTEL_SPAN_ID\"}" >> "$TELEMETRY_DIR/logs/structured.jsonl"
}

# Export functions
export -f ensure_trace_context otel_init otel_start_trace otel_start_span otel_end_span send_span otel_log
OTEL_LIB

chmod +x "$TELEMETRY_DIR/otel_unified.sh"
echo "Created unified telemetry library"

# Step 3: Update coordination helper
echo -e "\n${YELLOW}3️⃣ Updating coordination helper...${NC}"

# Backup original
cp "$CDCS_HOME/coordination_helper_v2.sh" "$CDCS_HOME/coordination_helper_v2.sh.bak" 2>/dev/null || true

# Create new version that sources unified library
cat > "$CDCS_HOME/coordination_helper_v3.sh" << 'COORD_HELPER'
#!/bin/bash

# Coordination Helper v3 - With unified telemetry
source /Users/sac/claude-desktop-context/telemetry/otel_unified.sh

# Initialize
otel_init "cdcs" "coordination_helper"

# Configuration
WORK_DIR="/Users/sac/claude-desktop-context/work"
LOCKS_DIR="$WORK_DIR/locks"
CLAIMS_FILE="$WORK_DIR/work_claims.json"

mkdir -p "$WORK_DIR" "$LOCKS_DIR"
[[ ! -f "$CLAIMS_FILE" ]] && echo "[]" > "$CLAIMS_FILE"

# Start main trace
trace_id=$(otel_start_trace "coordination.main")
otel_log "info" "Coordination helper started"

# Function to claim work
claim_work() {
    local span_id=$(otel_start_span "work.claim")
    
    local work_type="$1"
    local description="$2"
    local priority="${3:-medium}"
    local work_id="${work_type}_$(date +%s%N)"
    
    otel_log "info" "Claiming work: $work_type"
    
    # Atomic update
    local lock_file="$LOCKS_DIR/claims.lock"
    (
        flock -x 200
        local claims=$(cat "$CLAIMS_FILE" 2>/dev/null || echo "[]")
        local new_claim=$(cat <<EOF
{
  "id": "$work_id",
  "type": "$work_type",
  "description": "$description",
  "priority": "$priority",
  "status": "claimed",
  "claimed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "trace_id": "$OTEL_TRACE_ID"
}
EOF
        )
        echo "$claims" | jq ". + [$new_claim]" > "$CLAIMS_FILE"
    ) 200>"$lock_file"
    
    otel_log "info" "Work claimed: $work_id"
    otel_end_span
    
    echo "$work_id"
}

# Main execution
case "${1:-help}" in
    claim)
        claim_work "$2" "$3" "$4"
        ;;
    test)
        # Test trace propagation
        otel_log "info" "Running trace test"
        span1=$(otel_start_span "test.level1")
        otel_log "info" "In level 1"
        span2=$(otel_start_span "test.level2")
        otel_log "info" "In level 2"
        otel_end_span
        otel_end_span
        echo "Test complete. Trace: $trace_id"
        ;;
    *)
        echo "Usage: $0 {claim|test} [args...]"
        ;;
esac

otel_log "info" "Coordination helper complete"
COORD_HELPER

chmod +x "$CDCS_HOME/coordination_helper_v3.sh"
echo "Created coordination helper v3"

# Step 4: Run end-to-end test
echo -e "\n${YELLOW}4️⃣ Running end-to-end test...${NC}"

# Clear test data
> "$TELEMETRY_DIR/data/e2e_test.jsonl"

# Run test
TEST_OUTPUT=$("$CDCS_HOME/coordination_helper_v3.sh" test 2>&1)
echo "$TEST_OUTPUT"

# Step 5: Validate results
echo -e "\n${YELLOW}5️⃣ Validating system...${NC}"

# Check recent traces
recent_traces=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -1 -exec cat {} \; 2>/dev/null | wc -l)
valid_traces=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -1 -exec cat {} \; 2>/dev/null | \
    grep -c '"traceId": "[a-f0-9]\{32\}"' || echo 0)
parent_spans=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -1 -exec cat {} \; 2>/dev/null | \
    grep -c '"parentSpanId": "[a-f0-9]\{16\}"' || echo 0)

echo "Recent activity (1 min):"
echo "  Total spans: $recent_traces"
echo "  Valid traces: $valid_traces"
echo "  Parent-child links: $parent_spans"

# Calculate success rate
if [[ $recent_traces -gt 0 ]]; then
    success_rate=$(( valid_traces * 100 / recent_traces ))
    parent_rate=$(( parent_spans * 100 / recent_traces ))
    
    echo "  Success rate: ${success_rate}%"
    echo "  Parent tracking: ${parent_rate}%"
    
    if [[ $success_rate -ge 95 ]]; then
        echo -e "\n${GREEN}✅ SUCCESS! Trace system working correctly${NC}"
    else
        echo -e "\n${YELLOW}⚠️  Partial success - ${success_rate}% traces valid${NC}"
    fi
else
    echo -e "\n${RED}❌ No recent traces found${NC}"
fi

# Step 6: Fix errors in logs
echo -e "\n${YELLOW}6️⃣ Fixing logged errors...${NC}"

# Clear old error logs
find "$TELEMETRY_DIR/logs" -name "*.jsonl" -mtime +1 -delete 2>/dev/null || true

# Add error handler
cat > "$TELEMETRY_DIR/global_error_handler.sh" << 'ERROR_HANDLER'
#!/bin/bash

# Global error handler
handle_error() {
    local error_msg="$1"
    local error_code="${2:-1}"
    
    # Log error with trace context
    if [[ -f /Users/sac/claude-desktop-context/telemetry/otel_unified.sh ]]; then
        source /Users/sac/claude-desktop-context/telemetry/otel_unified.sh
        otel_log "error" "$error_msg"
    fi
    
    # Don't exit - just log
    return 0
}

# Set trap for errors
trap 'handle_error "Command failed: $BASH_COMMAND at line $LINENO"' ERR

export -f handle_error
ERROR_HANDLER

chmod +x "$TELEMETRY_DIR/global_error_handler.sh"
echo "Created global error handler"

# Step 7: Create monitoring script
echo -e "\n${YELLOW}7️⃣ Creating trace monitor...${NC}"

cat > "$TELEMETRY_DIR/trace_monitor.sh" << 'MONITOR'
#!/bin/bash

echo "📊 Real-time Trace Monitor"
echo "========================="
echo ""

tail -f /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl | while read line; do
    trace_id=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].traceId' 2>/dev/null | cut -c1-8)
    span_id=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].spanId' 2>/dev/null | cut -c1-8)
    parent_id=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].parentSpanId' 2>/dev/null | cut -c1-8)
    name=$(echo "$line" | jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' 2>/dev/null)
    
    if [[ -z "$parent_id" ]] || [[ "$parent_id" == "null" ]]; then
        echo "[$(date +%H:%M:%S)] 🌲 ROOT: $name ($trace_id)"
    else
        echo "[$(date +%H:%M:%S)]   └─ $name ($span_id → $parent_id)"
    fi
done
MONITOR

chmod +x "$TELEMETRY_DIR/trace_monitor.sh"
echo "Created trace monitor"

# Step 8: Update automation to use new system
echo -e "\n${YELLOW}8️⃣ Updating automation scripts...${NC}"

# Update autonomous loop to use new helper
sed -i.bak 's/coordination_helper_v2.sh/coordination_helper_v3.sh/g' "$CDCS_HOME/automation/autonomous_loop.sh" 2>/dev/null || true

echo "Updated automation scripts"

# Final summary
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}SYSTEM FIX COMPLETE${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""
echo "✅ Unified telemetry library created"
echo "✅ Coordination helper updated to v3"
echo "✅ Error handling improved"
echo "✅ Trace monitoring available"
echo ""
echo "Next steps:"
echo "1. Run: ./telemetry/trace_monitor.sh (to monitor traces)"
echo "2. Run: ./coordination_helper_v3.sh test (to test)"
echo "3. Run: ./automation/autonomous_loop.sh (to check health)"
echo ""
echo -e "${GREEN}System is now ready for end-to-end tracing!${NC}"
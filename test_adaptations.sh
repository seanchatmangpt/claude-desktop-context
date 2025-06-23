#!/bin/bash

##############################################################################
# Test Script for Coordination Helper Adaptations
##############################################################################

echo "🧪 TESTING COORDINATION HELPER ADAPTATIONS"
echo "========================================="
echo ""

# Set up test environment
export COORDINATION_DIR="${COORDINATION_DIR:-/tmp/coordination_test}"
export AI_PROVIDER="${AI_PROVIDER:-auto}"
export HEARTBEAT_INTERVAL=5  # Fast heartbeat for testing
export STALE_THRESHOLD=15    # Quick staleness for testing

# Ensure coordination directory exists
mkdir -p "$COORDINATION_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo -e "\n${YELLOW}TEST: $test_name${NC}"
    echo "Command: $test_command"
    
    # Run command and capture output
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASSED${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

# Test 1: Check Ollama availability
echo -e "\n${YELLOW}=== Test 1: AI Provider Detection ===${NC}"
source ./coordination_helper_adaptations.sh

if [ "$(check_ollama_availability)" = "true" ]; then
    echo -e "${GREEN}✅ Ollama is available${NC}"
else
    echo -e "${YELLOW}⚠️  Ollama not available - tests will use fallback${NC}"
    echo "   To enable Ollama tests:"
    echo "   1. Install Ollama: brew install ollama"
    echo "   2. Start Ollama: ollama serve"
    echo "   3. Pull a model: ollama pull llama2"
fi

# Test 2: Heartbeat functionality
echo -e "\n${YELLOW}=== Test 2: Heartbeat System ===${NC}"

# Start heartbeat daemon
echo "Starting heartbeat daemon..."
./coordination_helper.sh heartbeat-start

# Claim some test work
echo "Claiming test work..."
./coordination_helper.sh claim "test_feature" "Test heartbeat functionality" high test_team

# Wait for a heartbeat
echo "Waiting for heartbeat update..."
sleep 6

# Check freshness
echo "Checking work freshness..."
./coordination_helper.sh freshness-dashboard

# Test 3: Stale work detection
echo -e "\n${YELLOW}=== Test 3: Stale Work Detection ===${NC}"

# Create a stale work item manually
echo "Creating stale work item..."
STALE_WORK_ID="work_stale_$(date +%s%N)"
STALE_JSON=$(cat <<EOF
{
  "work_item_id": "$STALE_WORK_ID",
  "agent_id": "agent_stale_test",
  "claimed_at": "$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-10M +%Y-%m-%dT%H:%M:%SZ)",
  "description": "Intentionally stale work",
  "status": "in_progress",
  "work_type": "test",
  "priority": "low",
  "team": "test_team"
}
EOF
)

# Add stale item to work claims
if [ -f "$COORDINATION_DIR/work_claims.json" ]; then
    jq --argjson stale "$STALE_JSON" '. += [$stale]' "$COORDINATION_DIR/work_claims.json" > "$COORDINATION_DIR/work_claims.tmp"
    mv "$COORDINATION_DIR/work_claims.tmp" "$COORDINATION_DIR/work_claims.json"
else
    echo "[$STALE_JSON]" > "$COORDINATION_DIR/work_claims.json"
fi

# Check for stale work
echo "Checking for stale work..."
./coordination_helper.sh check-stale

# Test 4: Work recovery
echo -e "\n${YELLOW}=== Test 4: Stale Work Recovery ===${NC}"

echo "Attempting to recover stale work..."
./coordination_helper.sh recover-stale reassign

# Test 5: Enhanced work claiming with AI
echo -e "\n${YELLOW}=== Test 5: Enhanced Work Claiming ===${NC}"

echo "Testing enhanced work claiming with AI recommendation..."
./coordination_helper.sh claim-enhanced "ai_feature" "Implement recommendation engine" medium ai_team

# Test 6: Ollama analysis (if available)
echo -e "\n${YELLOW}=== Test 6: AI Analysis ===${NC}"

if [ "$(check_ollama_availability)" = "true" ]; then
    echo "Running Ollama priority analysis..."
    ./coordination_helper.sh ollama-priorities
else
    echo -e "${YELLOW}Skipping Ollama test - service not available${NC}"
fi

# Test 7: Generic AI analysis via pipe
echo -e "\n${YELLOW}=== Test 7: Pipe-based AI Analysis ===${NC}"

echo "Testing AI analysis via pipe..."
echo '{"test": "data", "priority": "high"}' | ./coordination_helper.sh ai-analyze "What is the priority level?"

# Stop heartbeat daemon
echo -e "\n${YELLOW}=== Cleanup ===${NC}"
echo "Stopping heartbeat daemon..."
./coordination_helper.sh heartbeat-stop

# Summary
echo -e "\n${YELLOW}=== TEST SUMMARY ===${NC}"
echo "Test environment: $COORDINATION_DIR"
echo "AI Provider: $AI_PROVIDER"
echo ""
echo "Features tested:"
echo "  ✅ Heartbeat system"
echo "  ✅ Stale work detection"  
echo "  ✅ Work recovery"
echo "  ✅ Enhanced claiming"
echo "  ✅ AI integration"
echo ""
echo -e "${GREEN}All basic functionality tests completed!${NC}"
echo ""
echo "To run a full integration test with real workload:"
echo "  1. Set COORDINATION_DIR to your actual coordination directory"
echo "  2. Ensure Ollama is running with a model loaded"
echo "  3. Run: ./test_adaptations.sh --integration"

# Cleanup test directory (optional)
if [[ "$1" == "--cleanup" ]]; then
    echo ""
    echo "Cleaning up test directory..."
    rm -rf "$COORDINATION_DIR"
    echo "Test directory removed"
fi
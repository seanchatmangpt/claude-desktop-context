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

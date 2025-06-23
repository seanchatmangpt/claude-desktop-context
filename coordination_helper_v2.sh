#!/bin/bash

##############################################################################
# CDCS Coordination Helper v2 - With Fixed OpenTelemetry
##############################################################################

# Fixed OpenTelemetry implementation inline
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"
OTEL_COLLECTOR_ENDPOINT="http://localhost:4318"

generate_trace_id() {
    od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-32
}

generate_span_id() {
    od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-16
}

get_timestamp_ns() {
    date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time() * 1000000000))"
}

# Initialize telemetry
export OTEL_SERVICE_NAME="cdcs"
export OTEL_COMPONENT_NAME="coordination_helper"
mkdir -p "$TELEMETRY_DIR"/{data,logs,metrics}

# Start trace for this script
export OTEL_TRACE_ID=$(generate_trace_id)
export OTEL_ROOT_SPAN_ID=$(generate_span_id)
export OTEL_SPAN_ID="$OTEL_ROOT_SPAN_ID"

# Send root span
send_span() {
    local trace_id="$1"
    local span_id="$2"
    local parent_id="$3"
    local name="$4"
    local timestamp="$5"
    
    cat >> "$TELEMETRY_DIR/data/traces.jsonl" <<EOF
{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"cdcs"}},{"key":"cdcs.component","value":{"stringValue":"coordination_helper"}}]},"scopeSpans":[{"spans":[{"traceId":"$trace_id","spanId":"$span_id","parentSpanId":"$parent_id","name":"$name","startTimeUnixNano":"$timestamp"}]}]}]}
EOF
}

# Start child span with proper parent tracking
start_span() {
    local name="$1"
    local parent="${OTEL_SPAN_ID:-$OTEL_ROOT_SPAN_ID}"
    local span_id=$(generate_span_id)
    
    # Store parent for restoration
    export "OTEL_PARENT_OF_$span_id=$parent"
    export OTEL_SPAN_ID="$span_id"
    
    send_span "$OTEL_TRACE_ID" "$span_id" "$parent" "$name" "$(get_timestamp_ns)"
    echo "$span_id"
}

end_span() {
    local parent_var="OTEL_PARENT_OF_$OTEL_SPAN_ID"
    export OTEL_SPAN_ID="${!parent_var}"
    unset "$parent_var"
}

# Log correlated with trace
log_message() {
    local level="$1"
    local msg="$2"
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"level\":\"$level\",\"message\":\"$msg\",\"trace_id\":\"$OTEL_TRACE_ID\",\"span_id\":\"$OTEL_SPAN_ID\"}" >> "$TELEMETRY_DIR/logs/structured.jsonl"
}

# Start root span
send_span "$OTEL_TRACE_ID" "$OTEL_ROOT_SPAN_ID" "" "coordination_helper.main" "$(get_timestamp_ns)"

# Configuration
WORK_DIR="${WORK_DIR:-/Users/sac/claude-desktop-context/work}"
LOCKS_DIR="$WORK_DIR/locks"
CLAIMS_FILE="$WORK_DIR/work_claims.json"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2}"

# Create directories
mkdir -p "$WORK_DIR" "$LOCKS_DIR"
touch "$CLAIMS_FILE"

# Function to claim work
claim_work() {
    span_id=$(start_span "work.claim")
    
    local work_type="$1"
    local description="$2"
    local priority="${3:-medium}"
    
    log_message "info" "Claiming work: $work_type - $description"
    
    # Generate work ID
    local work_id="${work_type}_$(date +%s%N)"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
    
    # Create claim JSON
    local claim_json=$(cat <<EOF
{
  "id": "$work_id",
  "type": "$work_type",
  "description": "$description",
  "priority": "$priority",
  "status": "claimed",
  "claimed_at": "$timestamp",
  "trace_id": "$OTEL_TRACE_ID",
  "span_id": "$span_id"
}
EOF
    )
    
    # Atomic write with lock
    local lock_file="$LOCKS_DIR/claims.lock"
    (
        flock -x 200
        
        # Read existing claims
        if [[ -s "$CLAIMS_FILE" ]]; then
            existing=$(cat "$CLAIMS_FILE")
            # Append new claim
            echo "$existing" | jq ". + [$claim_json]" > "$CLAIMS_FILE.tmp"
            mv "$CLAIMS_FILE.tmp" "$CLAIMS_FILE"
        else
            echo "[$claim_json]" > "$CLAIMS_FILE"
        fi
        
    ) 200>"$lock_file"
    
    log_message "info" "Successfully claimed work: $work_id"
    end_span
    
    echo "$work_id"
}

# Function to update progress
update_progress() {
    span_id=$(start_span "work.update_progress")
    
    local work_id="$1"
    local progress="$2"
    local details="$3"
    
    log_message "info" "Updating progress for $work_id: $progress%"
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
    
    # Update claims file
    local lock_file="$LOCKS_DIR/claims.lock"
    (
        flock -x 200
        
        if [[ -s "$CLAIMS_FILE" ]]; then
            jq --arg id "$work_id" --arg prog "$progress" --arg det "$details" --arg ts "$timestamp" \
               'map(if .id == $id then . + {"progress": ($prog | tonumber), "last_update": $ts, "details": $det} else . end)' \
               "$CLAIMS_FILE" > "$CLAIMS_FILE.tmp"
            mv "$CLAIMS_FILE.tmp" "$CLAIMS_FILE"
        fi
        
    ) 200>"$lock_file"
    
    end_span
}

# Function to complete work
complete_work() {
    span_id=$(start_span "work.complete")
    
    local work_id="$1"
    local result="$2"
    
    log_message "info" "Completing work: $work_id"
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
    
    # Update claims file
    local lock_file="$LOCKS_DIR/claims.lock"
    (
        flock -x 200
        
        if [[ -s "$CLAIMS_FILE" ]]; then
            jq --arg id "$work_id" --arg res "$result" --arg ts "$timestamp" \
               'map(if .id == $id then . + {"status": "completed", "completed_at": $ts, "result": $res} else . end)' \
               "$CLAIMS_FILE" > "$CLAIMS_FILE.tmp"
            mv "$CLAIMS_FILE.tmp" "$CLAIMS_FILE"
        fi
        
    ) 200>"$lock_file"
    
    log_message "info" "Work completed: $work_id"
    end_span
}

# Function to get AI analysis
get_ai_analysis() {
    span_id=$(start_span "ai.analysis")
    
    local prompt="$1"
    local context="$2"
    
    log_message "info" "Getting AI analysis"
    
    # Call Ollama
    local response=$(curl -s http://localhost:11434/api/generate \
        -d "{\"model\": \"$OLLAMA_MODEL\", \"prompt\": \"$context\n\n$prompt\", \"stream\": false}" \
        | jq -r '.response')
    
    log_message "info" "AI analysis complete"
    end_span
    
    echo "$response"
}

# Main execution
case "${1:-help}" in
    claim)
        claim_work "$2" "$3" "$4"
        ;;
    update)
        update_progress "$2" "$3" "$4"
        ;;
    complete)
        complete_work "$2" "$3"
        ;;
    analyze)
        get_ai_analysis "$2" "$3"
        ;;
    status)
        span_id=$(start_span "work.status")
        echo "Current work claims:"
        if [[ -s "$CLAIMS_FILE" ]]; then
            jq -r '.[] | "\(.id): \(.type) - \(.status) (\(.progress // 0)%)"' "$CLAIMS_FILE"
        else
            echo "No active claims"
        fi
        end_span
        ;;
    *)
        echo "CDCS Coordination Helper v2"
        echo "Usage: $0 {claim|update|complete|analyze|status} [args...]"
        echo ""
        echo "Commands:"
        echo "  claim <type> <description> [priority]  - Claim new work"
        echo "  update <work_id> <progress> <details>  - Update progress"
        echo "  complete <work_id> <result>            - Mark work as complete"
        echo "  analyze <prompt> <context>             - Get AI analysis"
        echo "  status                                 - Show current claims"
        ;;
esac

# Record metrics
echo "{\"name\":\"coordination.operations\",\"value\":1,\"type\":\"counter\",\"trace_id\":\"$OTEL_TRACE_ID\"}" >> "$TELEMETRY_DIR/metrics/metrics.jsonl"

# Final log
log_message "info" "Coordination helper execution complete"
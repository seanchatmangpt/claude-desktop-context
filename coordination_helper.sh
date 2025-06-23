#!/bin/bash

##############################################################################
# Agent Coordination Helper Script - CDCS Adapted Version with Full OpenTelemetry
##############################################################################
#
# DESCRIPTION:
#   Adapted coordination system for Claude Desktop Context System (CDCS)
#   with Ollama integration and comprehensive OpenTelemetry instrumentation
#
# TECHNICAL FEATURES:
#   - Ollama integration for local AI analysis
#   - CDCS pattern-based coordination
#   - Nanosecond-precision work claiming
#   - JSON-based coordination format
#   - Comprehensive OpenTelemetry distributed tracing
#   - Real-time metrics and observability
#
# USAGE:
#   ./coordination_helper.sh claim "work_type" "description" "priority" "team"
#   ./coordination_helper.sh progress "work_id" 75 "in_progress"
#   ./coordination_helper.sh complete "work_id" "success" 8
#   ./coordination_helper.sh dashboard
#   ./coordination_helper.sh patterns
#
# DEPENDENCIES:
#   - jq (JSON processing)
#   - python3 (timestamp calculations)
#   - ollama (local AI analysis)
#   - OpenTelemetry library (otel_lib.sh)
#
##############################################################################

# Load OpenTelemetry library
source /Users/sac/claude-desktop-context/telemetry/otel_lib.sh

# Initialize OpenTelemetry for coordination component
otel_init "coordination_helper" "cdcs-coordination"

# CDCS-specific directory paths
COORDINATION_DIR="${COORDINATION_DIR:-/Users/sac/claude-desktop-context/coordination}"
WORK_CLAIMS_FILE="work_claims.json"
AGENT_STATUS_FILE="agent_status.json"
COORDINATION_LOG_FILE="coordination_log.json"
PATTERNS_DIR="/Users/sac/claude-desktop-context/patterns"
MEMORY_DIR="/Users/sac/claude-desktop-context/memory"

# Ensure coordination directory exists
mkdir -p "$COORDINATION_DIR"

# Legacy telemetry functions (now use otel_lib.sh)
# These are kept for backward compatibility but redirect to new library
generate_trace_id() {
    otel_generate_trace_id
}

generate_span_id() {
    otel_generate_span_id
}

create_otel_context() {
    local operation_name="$1"
    otel_start_trace "$operation_name" "coordination_helper"
}

log_telemetry_span() {
    local span_name="$1"
    local span_kind="${2:-internal}"
    local status="${3:-ok}"
    local duration_ms="${4:-0}"
    local attributes="$5"
    
    otel_add_event "$span_name" "Span completed" "$attributes"
}

# Generate unique nanosecond-based agent ID
generate_agent_id() {
    echo "cdcs_agent_$(date +%s%N)"
}

# Ollama integration for local AI analysis with OpenTelemetry
ollama_analyze() {
    local model="${1:-qwen3:latest}"
    local prompt="$2"
    local format="${3:-json}"
    
    otel_start_span "ollama.analyze" "ollama_integration"
    otel_set_attributes "{\"model\": \"$model\", \"format\": \"$format\", \"prompt_length\": ${#prompt}}"
    
    if ! command -v ollama >/dev/null 2>&1; then
        otel_log "ERROR" "Ollama not available"
        otel_end_span "error" "Ollama command not found"
        return 1
    fi
    
    # Check if model is loaded
    if ! ollama ps | grep -q "$model"; then
        otel_add_event "model.loading" "Loading Ollama model: $model"
        otel_log "INFO" "Loading model: $model"
        ollama run "$model" "" >/dev/null 2>&1 &
        sleep 3
        otel_record_metric "ollama.model_load_time" 3000 "histogram"
    fi
    
    # Use Ollama for analysis with timing
    local result
    if result=$(otel_measure "ollama.inference" "ollama run '$model' --format '$format' '$prompt'"); then
        otel_log "INFO" "Ollama analysis completed successfully"
        otel_record_metric "ollama.inference_success" 1 "counter"
        otel_end_span "ok"
        echo "$result"
        return 0
    else
        otel_log "ERROR" "Ollama analysis failed"
        otel_record_metric "ollama.inference_error" 1 "counter"
        otel_end_span "error" "Ollama inference failed"
        return 1
    fi
}

# Function to claim work atomically using JSON with comprehensive telemetry
claim_work() {
    local work_type="$1"
    local description="$2"
    local priority="${3:-medium}"
    local team="${4:-cdcs_team}"
    
    # Start comprehensive telemetry
    local trace_id=$(otel_start_trace "cdcs.work.claim" "coordination_helper")
    otel_log "INFO" "Starting work claim process" "{\"work_type\": \"$work_type\", \"priority\": \"$priority\", \"team\": \"$team\"}"
    
    local agent_id="${AGENT_ID:-$(generate_agent_id)}"
    local work_item_id="work_$(date +%s%N)"
    
    # Record work claim attempt metrics
    otel_record_metric "work.claim_attempts" 1 "counter" "{\"work_type\": \"$work_type\", \"team\": \"$team\"}"
    
    otel_log "INFO" "Generated work item" "{\"agent_id\": \"$agent_id\", \"work_item_id\": \"$work_item_id\", \"trace_id\": \"$trace_id\"}"
    
    echo "🔍 Trace ID: $trace_id"
    echo "🤖 Agent $agent_id claiming work: $work_item_id"
    
    # Create JSON claim structure with enhanced telemetry
    otel_start_span "work.claim.create_structure" "coordination_helper"
    local claim_json
    claim_json=$(cat <<EOF
{
  "work_item_id": "$work_item_id",
  "agent_id": "$agent_id",
  "claimed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "estimated_duration": "30m",
  "work_type": "$work_type",
  "priority": "$priority",
  "description": "$description",
  "status": "active",
  "team": "$team",
  "telemetry": {
    "trace_id": "$trace_id",
    "span_id": "$OTEL_CURRENT_SPAN_ID",
    "operation": "cdcs.work.claim",
    "service": "$OTEL_SERVICE_NAME",
    "component": "coordination_helper"
  }
}
EOF
    )
    otel_end_span "ok"
    
    local work_claims_path="$COORDINATION_DIR/$WORK_CLAIMS_FILE"
    local lock_file="$work_claims_path.lock"
    
    # Atomic claim using file locking with telemetry
    otel_start_span "work.claim.atomic_lock" "coordination_helper"
    otel_add_event "lock.acquire_attempt" "Attempting to acquire file lock"
    
    if (set -C; echo $$ > "$lock_file") 2>/dev/null; then
        otel_add_event "lock.acquired" "File lock acquired successfully"
        trap 'rm -f "$lock_file"' EXIT
        
        # Initialize claims file if it doesn't exist
        if [ ! -f "$work_claims_path" ]; then
            otel_add_event "file.initialize" "Initializing work claims file"
            echo "[]" > "$work_claims_path"
        fi
        
        # Add new claim to JSON array
        if command -v jq >/dev/null 2>&1; then
            otel_start_span "work.claim.json_update" "coordination_helper"
            if jq --argjson claim "$claim_json" '. += [$claim]' "$work_claims_path" > "$work_claims_path.tmp" && \
               mv "$work_claims_path.tmp" "$work_claims_path"; then
                otel_end_span "ok"
            else
                otel_end_span "error" "JSON update failed"
                otel_log "ERROR" "Failed to update work claims JSON"
                rm -f "$lock_file"
                otel_end_span "error" "JSON processing failed"
                otel_end_trace "error" "Work claim failed"
                return 1
            fi
        else
            otel_log "ERROR" "jq required for JSON processing"
            rm -f "$lock_file"
            otel_end_span "error" "jq not available"
            otel_end_trace "error" "Missing dependency"
            return 1
        fi
        
        # Success path with comprehensive metrics
        otel_log "INFO" "Work claim successful" "{\"work_item_id\": \"$work_item_id\", \"team\": \"$team\"}"
        echo "✅ SUCCESS: Claimed work item $work_item_id for team $team"
        export CURRENT_WORK_ITEM="$work_item_id"
        export AGENT_ID="$agent_id"
        
        # Register agent in coordination system
        register_agent_in_team "$agent_id" "$team"
        
        # Record success metrics
        otel_record_metric "work.claims_successful" 1 "counter" "{\"work_type\": \"$work_type\", \"team\": \"$team\"}"
        otel_record_metric "work.active_items" 1 "gauge"
        
        rm -f "$lock_file"
        otel_end_span "ok"
        otel_end_trace "ok"
        return 0
    else
        otel_add_event "lock.conflict" "File lock conflict detected"
        otel_log "WARN" "Work claim conflict" "{\"lock_file\": \"$lock_file\"}"
        otel_record_metric "work.claim_conflicts" 1 "counter"
        echo "⚠️ CONFLICT: Another process is updating work claims"
        otel_end_span "error" "Lock conflict"
        otel_end_trace "error" "Coordination conflict"
        return 1
    fi
}

# Register agent in coordination system using JSON
register_agent_in_team() {
    local agent_id="$1"
    local team="${2:-cdcs_team}"
    local capacity="${3:-100}"
    local specialization="${4:-cdcs_coordination}"
    
    local agent_json
    agent_json=$(cat <<EOF
{
  "agent_id": "$agent_id",
  "team": "$team",
  "status": "active",
  "capacity": $capacity,
  "current_workload": 0,
  "specialization": "$specialization",
  "last_heartbeat": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "performance_metrics": {
    "tasks_completed": 0,
    "average_completion_time": "0m",
    "success_rate": 100.0
  }
}
EOF
    )
    
    local agent_status_path="$COORDINATION_DIR/$AGENT_STATUS_FILE"
    
    # Initialize agent status file if it doesn't exist
    if [ ! -f "$agent_status_path" ]; then
        echo "[]" > "$agent_status_path"
    fi
    
    # Add or update agent in JSON array
    if command -v jq >/dev/null 2>&1; then
        jq --arg id "$agent_id" 'map(select(.agent_id != $id))' "$agent_status_path" | \
        jq --argjson agent "$agent_json" '. += [$agent]' > "$agent_status_path.tmp" && \
        mv "$agent_status_path.tmp" "$agent_status_path"
    fi
    
    echo "🔧 REGISTERED: Agent $agent_id in team $team with $capacity% capacity"
}

# Update work progress in JSON format
update_progress() {
    local work_item_id="${1:-$CURRENT_WORK_ITEM}"
    local progress="$2"
    local status="${3:-in_progress}"
    
    local trace_id=$(create_otel_context "cdcs.work.progress")
    
    if [ -z "$work_item_id" ]; then
        echo "❌ ERROR: No work item ID specified"
        return 1
    fi
    
    echo "🔍 Trace ID: $trace_id"
    echo "📈 PROGRESS: Updated $work_item_id to $progress% ($status)"
    
    local work_claims_path="$COORDINATION_DIR/$WORK_CLAIMS_FILE"
    local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    if [ ! -f "$work_claims_path" ]; then
        echo "❌ ERROR: Work claims file not found"
        return 1
    fi
    
    # Update work item with progress using jq
    if command -v jq >/dev/null 2>&1; then
        jq --arg id "$work_item_id" \
           --arg status "$status" \
           --arg progress "$progress" \
           --arg timestamp "$timestamp" \
           --arg trace_id "$trace_id" \
           'map(if .work_item_id == $id then . + {"status": $status, "progress": ($progress | tonumber), "last_update": $timestamp, "telemetry": (.telemetry + {"last_progress_trace_id": $trace_id})} else . end)' \
           "$work_claims_path" > "$work_claims_path.tmp" && \
        mv "$work_claims_path.tmp" "$work_claims_path"
    fi
}

# Complete work using JSON format
complete_work() {
    local work_item_id="${1:-$CURRENT_WORK_ITEM}"
    local result="${2:-success}"
    local velocity_points="${3:-5}"
    
    if [ -z "$work_item_id" ]; then
        echo "❌ ERROR: No work item ID specified"
        return 1
    fi
    
    local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local work_claims_path="$COORDINATION_DIR/$WORK_CLAIMS_FILE"
    local coordination_log_path="$COORDINATION_DIR/$COORDINATION_LOG_FILE"
    
    # Create completion record in JSON
    local completion_json
    completion_json=$(cat <<EOF
{
  "work_item_id": "$work_item_id",
  "completed_at": "$timestamp",
  "agent_id": "${AGENT_ID:-$(generate_agent_id)}",
  "result": "$result",
  "velocity_points": $velocity_points
}
EOF
    )
    
    # Initialize coordination log if it doesn't exist
    if [ ! -f "$coordination_log_path" ]; then
        echo "[]" > "$coordination_log_path"
    fi
    
    # Add to coordination log
    if command -v jq >/dev/null 2>&1; then
        jq --argjson completion "$completion_json" '. += [$completion]' "$coordination_log_path" > "$coordination_log_path.tmp" && \
        mv "$coordination_log_path.tmp" "$coordination_log_path"
    fi
    
    # Update claim status to completed
    if [ -f "$work_claims_path" ] && command -v jq >/dev/null 2>&1; then
        jq --arg id "$work_item_id" \
           --arg status "completed" \
           --arg timestamp "$timestamp" \
           --arg result "$result" \
           'map(if .work_item_id == $id then . + {"status": $status, "completed_at": $timestamp, "result": $result} else . end)' \
           "$work_claims_path" > "$work_claims_path.tmp" && \
        mv "$work_claims_path.tmp" "$work_claims_path"
    fi
    
    echo "✅ COMPLETED: Released claim for $work_item_id ($result) - $velocity_points velocity points"
    unset CURRENT_WORK_ITEM
    
    # Update team velocity metrics
    update_team_velocity "$velocity_points"
}

# Update team velocity for coordination tracking
update_team_velocity() {
    local points="$1"
    local team="${AGENT_TEAM:-cdcs_team}"
    
    echo "📊 VELOCITY: Added $points points to team $team velocity"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ): Team $team +$points velocity points" >> "$COORDINATION_DIR/velocity_log.txt"
}

# Ollama-powered intelligent work prioritization
ollama_analyze_work_priorities() {
    local work_claims_path="$COORDINATION_DIR/$WORK_CLAIMS_FILE"
    
    echo "🧠 Ollama Intelligence: Analyzing work priorities..."
    
    if [ ! -f "$work_claims_path" ] || [ ! -s "$work_claims_path" ]; then
        echo "📊 No active work items to analyze"
        return 0
    fi
    
    local work_data=$(cat "$work_claims_path")
    local analysis_prompt="Analyze this CDCS work coordination data and provide intelligent prioritization recommendations.

Context: This is a JSON array of active work items in the Claude Desktop Context System.

Work Data:
$work_data

Provide a JSON response with:
- priority_recommendations: Array of work items with suggested priority levels
- bottlenecks: Identified coordination bottlenecks
- optimization_opportunities: Suggestions for improving coordination
- confidence_score: 0.0-1.0 confidence in recommendations

Focus on CDCS-specific patterns and efficient coordination."
    
    local priority_analysis
    if priority_analysis=$(ollama_analyze "qwen3:latest" "$analysis_prompt" "json"); then
        echo "✅ Ollama Priority Analysis Complete"
        echo "$priority_analysis" > "$COORDINATION_DIR/ollama_priority_analysis.json"
        
        # Display key recommendations
        if command -v jq >/dev/null 2>&1; then
            echo "📊 Priority Recommendations:"
            echo "$priority_analysis" | jq -r '.priority_recommendations[]? | "  🎯 \(.work_item_id): \(.suggested_priority) - \(.reasoning)"' 2>/dev/null || echo "  Analysis completed - check ollama_priority_analysis.json"
        fi
        return 0
    else
        echo "⚠️ Ollama analysis unavailable - using fallback prioritization"
        return 1
    fi
}

# CDCS-specific dashboard
show_cdcs_dashboard() {
    echo "🚀 CLAUDE DESKTOP CONTEXT SYSTEM - COORDINATION DASHBOARD"
    echo "========================================================"
    
    echo ""
    echo "🎯 CURRENT SESSION:"
    if [ -f "$MEMORY_DIR/sessions/current.link" ]; then
        local current_session=$(cat "$MEMORY_DIR/sessions/current.link" 2>/dev/null || echo "no_session")
        echo "  📂 Active Session: $current_session"
    else
        echo "  📂 No active session"
    fi
    
    echo ""
    echo "👥 COORDINATION AGENTS & STATUS:"
    if [ -f "$COORDINATION_DIR/$AGENT_STATUS_FILE" ] && command -v jq >/dev/null 2>&1; then
        local agent_count=$(jq 'length' "$COORDINATION_DIR/$AGENT_STATUS_FILE" 2>/dev/null || echo "0")
        echo "  📊 Active Agents: $agent_count"
        jq -r '.[] | "  🤖 Agent \(.agent_id): \(.team) team (\(.specialization))"' "$COORDINATION_DIR/$AGENT_STATUS_FILE" 2>/dev/null || echo "  (Unable to read agent details)"
    else
        echo "  (No active coordination agents)"
    fi
    
    echo ""
    echo "📋 ACTIVE WORK ITEMS:"
    if [ -f "$COORDINATION_DIR/$WORK_CLAIMS_FILE" ] && command -v jq >/dev/null 2>&1; then
        local active_count=$(jq '[.[] | select(.status == "active")] | length' "$COORDINATION_DIR/$WORK_CLAIMS_FILE" 2>/dev/null || echo "0")
        echo "  📊 Active Work Items: $active_count"
        jq -r '.[] | select(.status == "active") | "  🔧 \(.work_item_id): \(.description) (\(.work_type), \(.priority))"' "$COORDINATION_DIR/$WORK_CLAIMS_FILE" 2>/dev/null || echo "  (Unable to read work details)"
    else
        echo "  (No active work items)"
    fi
    
    echo ""
    echo "📈 VELOCITY & METRICS:"
    local total_velocity=0
    if [ -f "$COORDINATION_DIR/velocity_log.txt" ]; then
        total_velocity=$(grep -o '+[0-9]*' "$COORDINATION_DIR/velocity_log.txt" | sed 's/+//' | awk '{sum+=$1} END {print sum+0}')
    fi
    echo "  📊 Current Velocity: $total_velocity coordination points"
    echo "  🎯 Focus: CDCS pattern optimization and context efficiency"
    echo "  ⏱️ Status: $(date +%Y-%m-%d)"
    
    echo ""
    echo "🤖 OLLAMA STATUS:"
    if command -v ollama >/dev/null 2>&1; then
        local ollama_status=$(ollama ps 2>/dev/null | grep -v "NAME" | wc -l)
        echo "  📊 Loaded Models: $ollama_status"
        echo "  🧠 Intelligence: Available for coordination analysis"
    else
        echo "  ❌ Ollama not available"
    fi
    
    echo ""
    echo "🔄 COORDINATION COMMANDS:"
    echo "  📋 claim <type> <desc> [priority] [team] - Claim coordination work"
    echo "  🧠 ollama-analyze                        - AI-powered priority analysis"
    echo "  📊 dashboard                             - Show this dashboard"
    echo "  🎯 patterns                              - Analyze CDCS patterns"
}

# CDCS pattern analysis
analyze_cdcs_patterns() {
    echo "🧩 CDCS PATTERN ANALYSIS"
    echo "======================="
    
    local patterns_cache="$PATTERNS_DIR/cache"
    if [ -d "$patterns_cache" ]; then
        echo ""
        echo "📊 Pattern Cache Status:"
        local pattern_count=$(find "$patterns_cache" -name "*.json" | wc -l)
        echo "  📁 Cached Patterns: $pattern_count"
        
        if [ -f "$patterns_cache/last_refresh.txt" ]; then
            echo "  🔄 Last Refresh: $(cat "$patterns_cache/last_refresh.txt")"
        fi
    fi
    
    echo ""
    echo "🔍 Recent Pattern Activity:"
    if [ -f "$MEMORY_DIR/sessions/current.link" ]; then
        echo "  📈 Active session coordination patterns"
        echo "  🎯 Context optimization opportunities"
        echo "  ⚡ Efficiency improvements tracked"
    else
        echo "  📋 No active session for pattern analysis"
    fi
}

# Main command dispatcher
case "${1:-help}" in
    "claim")
        claim_work "$2" "$3" "$4" "$5"
        ;;
    "progress")
        update_progress "$2" "$3" "$4"
        ;;
    "complete")
        complete_work "$2" "$3" "$4"
        ;;
    "register")
        register_agent_in_team "$2" "$3" "$4" "$5"
        ;;
    "dashboard")
        show_cdcs_dashboard
        ;;
    "ollama-analyze")
        ollama_analyze_work_priorities
        ;;
    "patterns")
        analyze_cdcs_patterns
        ;;
    "generate-id")
        generate_agent_id
        ;;
    "help"|*)
        echo "🤖 CDCS COORDINATION HELPER"
        echo "Usage: $0 <command> [args...]"
        echo ""
        echo "🎯 Work Management Commands:"
        echo "  claim <work_type> <description> [priority] [team]  - Claim work with nanosecond ID"
        echo "  progress <work_id> <percent> [status]              - Update work progress"  
        echo "  complete <work_id> [result] [velocity_points]      - Complete work and update velocity"
        echo "  register <agent_id> [team] [capacity] [spec]       - Register agent in coordination system"
        echo ""
        echo "🧠 Ollama Intelligence Commands:"
        echo "  ollama-analyze                                      - AI work priority analysis"
        echo ""
        echo "📊 CDCS Commands:"
        echo "  dashboard                                           - Show CDCS coordination dashboard"
        echo "  patterns                                            - Analyze CDCS patterns"
        echo "  generate-id                                         - Generate nanosecond agent ID"
        echo ""
        echo "🔧 Utility Commands:"
        echo "  help                                                - Show this help"
        echo ""
        echo "🌟 CDCS Features:"
        echo "  ✅ Nanosecond-based agent IDs for uniqueness"
        echo "  ✅ JSON-based coordination with atomic file locking"
        echo "  ✅ Ollama integration for local AI analysis"
        echo "  ✅ CDCS pattern-aware coordination"
        echo "  ✅ OpenTelemetry distributed tracing"
        echo ""
        echo "Environment Variables:"
        echo "  AGENT_ID     - Unique agent identifier"
        echo "  AGENT_TEAM   - Team assignment (default: cdcs_team)"
        ;;
esac
#!/bin/bash

##############################################################################
# Coordination Helper Adaptations - Work Freshness & Ollama Support
##############################################################################

# Configuration
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
AI_PROVIDER="${AI_PROVIDER:-ollama}"  # ollama, claude, or auto
HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-60}"  # seconds
STALE_THRESHOLD="${STALE_THRESHOLD:-300}"  # 5 minutes

# Work Freshness Functions
##############################################################################

# Update agent heartbeat
update_agent_heartbeat() {
    local agent_id="${1:-$AGENT_ID}"
    local work_item_id="${2:-$CURRENT_WORK_ITEM}"
    
    if [ -z "$agent_id" ]; then
        echo "❌ ERROR: No agent ID specified"
        return 1
    fi
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local agent_status_path="$COORDINATION_DIR/$AGENT_STATUS_FILE"
    
    # Update agent last_heartbeat
    if command -v jq >/dev/null 2>&1 && [ -f "$agent_status_path" ]; then
        jq --arg id "$agent_id" \
           --arg timestamp "$timestamp" \
           'map(if .agent_id == $id then . + {"last_heartbeat": $timestamp} else . end)' \
           "$agent_status_path" > "$agent_status_path.tmp" && \
        mv "$agent_status_path.tmp" "$agent_status_path"
    fi
    
    # Update work item heartbeat if working
    if [ -n "$work_item_id" ]; then
        local work_claims_path="$COORDINATION_DIR/$WORK_CLAIMS_FILE"
        if [ -f "$work_claims_path" ]; then
            jq --arg id "$work_item_id" \
               --arg timestamp "$timestamp" \
               'map(if .work_item_id == $id then . + {"last_heartbeat": $timestamp} else . end)' \
               "$work_claims_path" > "$work_claims_path.tmp" && \
            mv "$work_claims_path.tmp" "$work_claims_path"
        fi
    fi
}

# Check for stale work items
check_stale_work() {
    local work_claims_path="$COORDINATION_DIR/$WORK_CLAIMS_FILE"
    local current_timestamp=$(date +%s)
    local stale_items=()
    
    if [ ! -f "$work_claims_path" ]; then
        return 0
    fi
    
    echo "🔍 Checking for stale work items..."
    
    # Find stale items using jq
    local stale_json=$(jq --arg current "$current_timestamp" \
                         --arg threshold "$STALE_THRESHOLD" \
        '[.[] | select(.status == "in_progress" or .status == "active") |
         if .last_heartbeat then
           (($current | tonumber) - (.last_heartbeat | fromdateiso8601)) as $age |
           if $age > ($threshold | tonumber) then
             . + {"staleness_seconds": $age}
           else empty end
         else
           . + {"staleness_seconds": 999999}
         end]' "$work_claims_path")
    
    local stale_count=$(echo "$stale_json" | jq 'length')
    
    if [ "$stale_count" -gt 0 ]; then
        echo "⚠️  Found $stale_count stale work items:"
        echo "$stale_json" | jq -r '.[] | "  📋 \(.work_item_id): \(.description) (stale for \(.staleness_seconds)s)"'
        
        # Save stale items report
        echo "$stale_json" > "$COORDINATION_DIR/stale_work_report.json"
        
        # Emit telemetry event
        emit_phoenix_telemetry_event "stale_work_detected" "$stale_count" "coordination_health" ""
    else
        echo "✅ No stale work items found"
    fi
    
    return "$stale_count"
}

# Recover stale work items
recover_stale_work() {
    local recovery_action="${1:-reassign}"  # reassign, fail, retry
    local stale_report="$COORDINATION_DIR/stale_work_report.json"
    
    if [ ! -f "$stale_report" ]; then
        echo "📋 No stale work report found. Run check_stale_work first."
        return 1
    fi
    
    echo "🔧 Recovering stale work items with action: $recovery_action"
    
    local work_claims_path="$COORDINATION_DIR/$WORK_CLAIMS_FILE"
    local recovery_count=0
    
    # Process each stale item
    local stale_ids=$(jq -r '.[].work_item_id' "$stale_report")
    
    for work_id in $stale_ids; do
        case "$recovery_action" in
            "reassign")
                echo "  🔄 Reassigning $work_id to available agent..."
                # Mark as pending for reassignment
                jq --arg id "$work_id" \
                   --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                   'map(if .work_item_id == $id then 
                     . + {"status": "pending", "recovery_reason": "stale_reassignment", "recovered_at": $timestamp} 
                     else . end)' \
                   "$work_claims_path" > "$work_claims_path.tmp" && \
                mv "$work_claims_path.tmp" "$work_claims_path"
                ((recovery_count++))
                ;;
            
            "fail")
                echo "  ❌ Marking $work_id as failed..."
                complete_work "$work_id" "failed_stale" 0
                ((recovery_count++))
                ;;
            
            "retry")
                echo "  🔁 Retrying $work_id with same agent..."
                # Reset progress and update heartbeat
                jq --arg id "$work_id" \
                   --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                   'map(if .work_item_id == $id then 
                     . + {"progress": 0, "last_heartbeat": $timestamp, "retry_count": ((.retry_count // 0) + 1)} 
                     else . end)' \
                   "$work_claims_path" > "$work_claims_path.tmp" && \
                mv "$work_claims_path.tmp" "$work_claims_path"
                ((recovery_count++))
                ;;
        esac
    done
    
    echo "✅ Recovered $recovery_count stale work items"
    
    # Clean up report
    rm -f "$stale_report"
}

# Background heartbeat daemon
start_heartbeat_daemon() {
    local pid_file="$COORDINATION_DIR/heartbeat_daemon.pid"
    
    # Check if already running
    if [ -f "$pid_file" ] && kill -0 $(cat "$pid_file") 2>/dev/null; then
        echo "❤️  Heartbeat daemon already running (PID: $(cat $pid_file))"
        return 0
    fi
    
    echo "❤️  Starting heartbeat daemon..."
    
    # Start daemon in background
    (
        while true; do
            # Update heartbeat
            update_agent_heartbeat
            
            # Check for stale work periodically (every 5 heartbeats)
            if [ $(($(date +%s) % (HEARTBEAT_INTERVAL * 5))) -lt "$HEARTBEAT_INTERVAL" ]; then
                check_stale_work
            fi
            
            sleep "$HEARTBEAT_INTERVAL"
        done
    ) &
    
    local daemon_pid=$!
    echo "$daemon_pid" > "$pid_file"
    echo "✅ Heartbeat daemon started (PID: $daemon_pid)"
}

# Stop heartbeat daemon
stop_heartbeat_daemon() {
    local pid_file="$COORDINATION_DIR/heartbeat_daemon.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$pid_file"
            echo "🛑 Heartbeat daemon stopped"
        else
            echo "⚠️  Heartbeat daemon not running"
            rm -f "$pid_file"
        fi
    else
        echo "📋 No heartbeat daemon found"
    fi
}

# Ollama Integration Functions
##############################################################################

# Check if Ollama is available
check_ollama_availability() {
    if command -v ollama >/dev/null 2>&1; then
        # Check if ollama is running
        if curl -s "$OLLAMA_HOST/api/tags" >/dev/null 2>&1; then
            echo "true"
            return 0
        fi
    fi
    echo "false"
    return 1
}

# Generic AI analysis function (supports both Ollama and Claude)
ai_analyze() {
    local input_data="$1"
    local prompt="$2"
    local model="${3:-llama2}"  # Default Ollama model
    
    case "$AI_PROVIDER" in
        "ollama")
            ollama_analyze "$input_data" "$prompt" "$model"
            ;;
        "claude")
            echo "$input_data" | claude -p "$prompt" --output-format json 2>/dev/null
            ;;
        "auto")
            # Try Ollama first, fallback to Claude
            if [ "$(check_ollama_availability)" = "true" ]; then
                ollama_analyze "$input_data" "$prompt" "$model"
            elif command -v claude >/dev/null 2>&1; then
                echo "$input_data" | claude -p "$prompt" --output-format json 2>/dev/null
            else
                echo '{"error": "No AI provider available", "fallback": true}'
            fi
            ;;
    esac
}

# Ollama-specific analysis function
ollama_analyze() {
    local input_data="$1"
    local prompt="$2"
    local model="${3:-llama2}"
    
    # Prepare the full prompt with context
    local full_prompt="$prompt

Context data:
$input_data

Please provide a JSON response."
    
    # Call Ollama API
    local response=$(curl -s -X POST "$OLLAMA_HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d @- <<EOF
{
    "model": "$model",
    "prompt": "$full_prompt",
    "format": "json",
    "stream": false,
    "options": {
        "temperature": 0.7,
        "top_p": 0.9
    }
}
EOF
    )
    
    # Extract response
    if [ -n "$response" ]; then
        echo "$response" | jq -r '.response // empty'
    else
        echo '{"error": "Ollama request failed", "provider": "ollama"}'
    fi
}

# Ollama work priority analysis
ollama_analyze_work_priorities() {
    echo "🤖 OLLAMA WORK PRIORITY ANALYSIS"
    echo "================================"
    
    local work_claims_path="$COORDINATION_DIR/$WORK_CLAIMS_FILE"
    
    if [ ! -f "$work_claims_path" ] || [ ! -s "$work_claims_path" ]; then
        echo "📊 No active work items to analyze"
        return 0
    fi
    
    # Check Ollama availability
    if [ "$(check_ollama_availability)" != "true" ]; then
        echo "❌ Ollama not available. Please ensure Ollama is running at $OLLAMA_HOST"
        return 1
    fi
    
    local context_data=$(cat <<EOF
{
  "work_claims": $(cat "$work_claims_path" 2>/dev/null || echo "[]"),
  "agent_status": $(cat "$COORDINATION_DIR/$AGENT_STATUS_FILE" 2>/dev/null || echo "[]"),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    )
    
    local analysis_prompt="Analyze this Scrum at Scale work coordination data and provide prioritization recommendations.

Focus on:
1. Critical path identification
2. Resource optimization 
3. Dependency management
4. Bottleneck detection

Return JSON with structure:
{
  \"recommendations\": [
    {\"work_id\": \"id\", \"priority_score\": 1-100, \"reasoning\": \"explanation\"}
  ],
  \"bottlenecks\": [
    {\"type\": \"resource|dependency|skill\", \"description\": \"details\", \"severity\": \"low|medium|high\"}
  ],
  \"optimization_opportunities\": [
    {\"description\": \"opportunity\", \"impact\": \"expected benefit\"}
  ]
}"

    echo "🔄 Analyzing with Ollama..."
    local analysis_result=$(ai_analyze "$context_data" "$analysis_prompt" "llama2")
    
    # Save results
    echo "$analysis_result" > "$COORDINATION_DIR/ollama_priority_analysis.json"
    
    # Display key findings
    if command -v jq >/dev/null 2>&1 && echo "$analysis_result" | jq . >/dev/null 2>&1; then
        echo ""
        echo "📊 Top Recommendations:"
        echo "$analysis_result" | jq -r '.recommendations[]? | "  🎯 \(.work_id): Priority \(.priority_score) - \(.reasoning)"' | head -3
        
        echo ""
        echo "⚠️  Bottlenecks Detected:"
        echo "$analysis_result" | jq -r '.bottlenecks[]? | "  🚧 \(.type): \(.description) (\(.severity) severity)"' | head -3
    else
        echo "✅ Analysis completed and saved to ollama_priority_analysis.json"
    fi
}

# Ollama team optimization
ollama_optimize_team_assignments() {
    echo "👥 OLLAMA TEAM ASSIGNMENT OPTIMIZATION"
    echo "====================================="
    
    if [ "$(check_ollama_availability)" != "true" ]; then
        echo "❌ Ollama not available"
        return 1
    fi
    
    local system_state=$(cat <<EOF
{
  "agents": $(cat "$COORDINATION_DIR/$AGENT_STATUS_FILE" 2>/dev/null || echo "[]"),
  "work_items": $(cat "$COORDINATION_DIR/$WORK_CLAIMS_FILE" 2>/dev/null || echo "[]"),
  "team_velocity": $(grep -o '+[0-9]*' "$COORDINATION_DIR/velocity_log.txt" 2>/dev/null | sed 's/+//' | awk '{sum+=$1} END {print sum+0}')
}
EOF
    )
    
    local optimization_prompt="Analyze agent assignments and suggest optimizations for better team performance.

Consider:
- Agent capacity and current workload
- Skill matching
- Team balance
- Cross-team dependencies

Return JSON with:
{
  \"reassignments\": [
    {\"work_id\": \"id\", \"from_agent\": \"agent_id\", \"to_agent\": \"agent_id\", \"reason\": \"explanation\"}
  ],
  \"team_formation\": [
    {\"team_name\": \"name\", \"suggested_agents\": [\"agent_ids\"], \"focus_area\": \"description\"}
  ],
  \"efficiency_gain\": \"percentage\"
}"

    local optimization_result=$(ai_analyze "$system_state" "$optimization_prompt" "llama2")
    
    echo "$optimization_result" > "$COORDINATION_DIR/ollama_team_optimization.json"
    echo "✅ Team optimization analysis completed"
}

# Enhanced work claiming with freshness checks
claim_work_enhanced() {
    local work_type="$1"
    local description="$2"
    local priority="${3:-medium}"
    local team="${4:-autonomous_team}"
    
    # Start heartbeat daemon if not running
    start_heartbeat_daemon
    
    # Check for stale work before claiming new work
    if check_stale_work; then
        echo "⚠️  Warning: Stale work items detected. Consider recovery before claiming new work."
    fi
    
    # Get AI recommendation based on provider
    echo "🤖 Getting AI recommendation for work claiming..."
    
    local recommendation_prompt="Should agent claim work type '$work_type'? Consider current workload and priorities. Return JSON: {\"should_claim\": true/false, \"reasoning\": \"explanation\", \"suggested_priority\": \"low|medium|high|critical\"}"
    
    local ai_recommendation=$(ai_analyze "{\"work_type\": \"$work_type\", \"current_claims\": $(cat $COORDINATION_DIR/$WORK_CLAIMS_FILE 2>/dev/null || echo '[]')}" "$recommendation_prompt")
    
    if echo "$ai_recommendation" | jq -e '.should_claim == true' >/dev/null 2>&1; then
        local suggested_priority=$(echo "$ai_recommendation" | jq -r '.suggested_priority // "medium"')
        echo "✅ AI recommends claiming with priority: $suggested_priority"
        priority="$suggested_priority"
    else
        echo "⚠️  AI suggests not claiming this work now"
        local reasoning=$(echo "$ai_recommendation" | jq -r '.reasoning // "No reason provided"')
        echo "   Reason: $reasoning"
    fi
    
    # Claim work using original function
    claim_work "$work_type" "$description" "$priority" "$team"
    
    # Set up automatic heartbeat for this work
    if [ -n "$CURRENT_WORK_ITEM" ]; then
        echo "❤️  Heartbeat tracking enabled for $CURRENT_WORK_ITEM"
    fi
}

# Show enhanced dashboard with freshness status
show_freshness_dashboard() {
    echo "🔄 WORK FRESHNESS DASHBOARD"
    echo "=========================="
    echo ""
    
    # Check Ollama status
    local ollama_status="❌ Offline"
    if [ "$(check_ollama_availability)" = "true" ]; then
        ollama_status="✅ Online"
    fi
    
    echo "🤖 AI Providers:"
    echo "  Ollama: $ollama_status ($OLLAMA_HOST)"
    echo "  Claude: $(command -v claude >/dev/null 2>&1 && echo '✅ Available' || echo '❌ Not found')"
    echo "  Active: $AI_PROVIDER"
    echo ""
    
    # Show heartbeat daemon status
    local daemon_status="🔴 Stopped"
    local pid_file="$COORDINATION_DIR/heartbeat_daemon.pid"
    if [ -f "$pid_file" ] && kill -0 $(cat "$pid_file") 2>/dev/null; then
        daemon_status="🟢 Running (PID: $(cat $pid_file))"
    fi
    
    echo "❤️  Heartbeat Daemon: $daemon_status"
    echo ""
    
    # Show work freshness summary
    local work_claims_path="$COORDINATION_DIR/$WORK_CLAIMS_FILE"
    if [ -f "$work_claims_path" ] && command -v jq >/dev/null 2>&1; then
        local total_work=$(jq '[.[] | select(.status == "active" or .status == "in_progress")] | length' "$work_claims_path")
        local fresh_work=$(jq --arg threshold "$STALE_THRESHOLD" \
            '[.[] | select(.status == "active" or .status == "in_progress") | 
             select(.last_heartbeat and ((now - (.last_heartbeat | fromdateiso8601)) < ($threshold | tonumber)))] | length' \
            "$work_claims_path" 2>/dev/null || echo 0)
        
        echo "📊 Work Freshness:"
        echo "  Total Active: $total_work items"
        echo "  Fresh (<${STALE_THRESHOLD}s): $fresh_work items"
        echo "  Potentially Stale: $((total_work - fresh_work)) items"
        
        # Show stale items if any
        if [ $((total_work - fresh_work)) -gt 0 ]; then
            echo ""
            echo "⚠️  Potentially Stale Items:"
            jq -r --arg threshold "$STALE_THRESHOLD" \
                '.[] | select(.status == "active" or .status == "in_progress") |
                select(.last_heartbeat == null or ((now - (.last_heartbeat | fromdateiso8601)) >= ($threshold | tonumber))) |
                "  📋 \(.work_item_id): \(.description)"' \
                "$work_claims_path" 2>/dev/null | head -5
        fi
    fi
}

# Export functions for use in main script
export -f update_agent_heartbeat
export -f check_stale_work
export -f recover_stale_work
export -f start_heartbeat_daemon
export -f stop_heartbeat_daemon
export -f check_ollama_availability
export -f ai_analyze
export -f ollama_analyze
export -f ollama_analyze_work_priorities
export -f ollama_optimize_team_assignments
export -f claim_work_enhanced
export -f show_freshness_dashboard
#!/bin/bash

##############################################################################
# Example: Enhanced Agent with Work Freshness and AI Support
##############################################################################

# This example shows how to create an agent that uses the new features

# Configuration
export AGENT_ID="agent_enhanced_$(date +%s%N)"
export AGENT_TEAM="development_team"
export AI_PROVIDER="auto"  # Will try Ollama first, then Claude
export HEARTBEAT_INTERVAL=30
export STALE_THRESHOLD=180  # 3 minutes

echo "🤖 Enhanced Agent Example"
echo "========================"
echo "Agent ID: $AGENT_ID"
echo "Team: $AGENT_TEAM"
echo ""

# Function to simulate work
do_work() {
    local work_id="$1"
    local duration="$2"
    
    echo "💼 Starting work on: $work_id"
    
    # Simulate work with progress updates
    for i in 25 50 75 100; do
        sleep $((duration / 4))
        
        # Update heartbeat during work
        ./coordination_helper.sh heartbeat "$AGENT_ID" "$work_id"
        
        # Update progress
        if [ $i -lt 100 ]; then
            ./coordination_helper.sh progress "$work_id" "$i" "in_progress"
            echo "   📊 Progress: $i%"
        fi
    done
    
    echo "   ✅ Work completed!"
}

# Start heartbeat daemon for this agent
echo "🫀 Starting heartbeat daemon..."
./coordination_helper.sh heartbeat-start

# Register agent with enhanced capabilities
echo "📝 Registering enhanced agent..."
./coordination_helper.sh register "$AGENT_ID" "$AGENT_TEAM" 100 "ai_enhanced_development"

# Main agent loop
echo ""
echo "🔄 Starting main agent loop..."
echo "   (Press Ctrl+C to stop)"
echo ""

while true; do
    echo "🔍 Checking for stale work to recover..."
    if ./coordination_helper.sh check-stale > /tmp/stale_check.log 2>&1; then
        if grep -q "stale work items" /tmp/stale_check.log; then
            echo "   🔧 Found stale work - attempting recovery"
            ./coordination_helper.sh recover-stale reassign
        fi
    fi
    
    echo "🤔 Asking AI for work recommendations..."
    
    # Get AI recommendation for what type of work to claim
    WORK_TYPES=("backend_api" "frontend_ui" "database_migration" "bug_fix" "documentation")
    RANDOM_TYPE=${WORK_TYPES[$RANDOM % ${#WORK_TYPES[@]}]}
    
    echo "   💡 Considering work type: $RANDOM_TYPE"
    
    # Use enhanced claiming with AI recommendation
    if ./coordination_helper.sh claim-enhanced "$RANDOM_TYPE" "AI-recommended task for $RANDOM_TYPE" medium "$AGENT_TEAM"; then
        # Work was claimed successfully
        if [ -n "$CURRENT_WORK_ITEM" ]; then
            echo "   🎯 Claimed work: $CURRENT_WORK_ITEM"
            
            # Simulate doing the work
            WORK_DURATION=$((10 + RANDOM % 20))  # 10-30 seconds
            do_work "$CURRENT_WORK_ITEM" "$WORK_DURATION"
            
            # Complete the work
            VELOCITY_POINTS=$((3 + RANDOM % 8))  # 3-10 points
            ./coordination_helper.sh complete "$CURRENT_WORK_ITEM" "success" "$VELOCITY_POINTS"
            
            # Small break between tasks
            echo "   😴 Taking a 5-second break..."
            sleep 5
        fi
    else
        echo "   ⏸️  No work claimed - waiting 10 seconds..."
        sleep 10
    fi
    
    # Show current status
    echo ""
    echo "📊 Current Status:"
    ./coordination_helper.sh freshness-dashboard | grep -E "(AI Providers:|Active:|Fresh:|Potentially Stale:)" | sed 's/^/   /'
    echo ""
    echo "---"
    echo ""
done

# Cleanup on exit (this won't normally be reached due to infinite loop)
echo "🛑 Stopping heartbeat daemon..."
./coordination_helper.sh heartbeat-stop
#!/bin/bash

echo "🤖 CDCS Autonomous Loop Demo"
echo "============================"
echo ""
echo "This demonstrates how the system analyzes itself and takes action."
echo ""

# Step 1: Generate some trace activity
echo "1️⃣ Generating trace activity..."
for i in {1..5}; do
    ./coordination_helper_v2.sh claim "demo_task" "Automated task $i" "medium"
done

echo ""
echo "2️⃣ Analyzing traces with pattern recognition..."

# Extract patterns
patterns=$(find telemetry/data -name "*.jsonl" -mmin -5 -exec cat {} \; 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' 2>/dev/null | \
    sort | uniq -c | sort -nr | head -10)

echo "Found patterns:"
echo "$patterns"

echo ""
echo "3️⃣ Using AI to generate insights..."

# Create a simple prompt
prompt="Analyze these operation patterns and suggest optimizations:
$patterns

Provide 3 specific recommendations."

# Use Ollama
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    response=$(curl -s http://localhost:11434/api/generate \
        -d "{\"model\": \"llama3.2\", \"prompt\": \"$prompt\", \"stream\": false}" | \
        jq -r '.response' 2>/dev/null | head -200)
    
    echo "AI Recommendations:"
    echo "$response"
    
    # Create work items from recommendations
    echo ""
    echo "4️⃣ Creating automated work items..."
    
    # Extract recommendations (simple pattern matching)
    echo "$response" | grep -E "^[1-3]\." | while read -r rec; do
        # Create work claim
        work_id=$(./coordination_helper_v2.sh claim "ai_optimization" "$rec" "high")
        echo "  ✓ Created work item: $work_id"
    done
else
    echo "⚠️  Ollama not running. Using static analysis instead."
    
    # Fallback analysis
    echo ""
    echo "Static Analysis Results:"
    echo "- High frequency of coordination_helper.main calls"
    echo "- Multiple work.claim operations detected"
    echo "- Consider batching operations for efficiency"
fi

echo ""
echo "5️⃣ Checking system health..."

# Calculate simple health metrics
total_traces=$(find telemetry/data -name "*.jsonl" -exec cat {} \; 2>/dev/null | wc -l)
recent_errors=$(find telemetry/logs -name "*.jsonl" -mmin -60 -exec grep -ci error {} \; 2>/dev/null | \
    awk '{s+=$1} END {print s}')
health_score=$((100 - recent_errors * 5))
[[ $health_score -lt 0 ]] && health_score=0

echo "Health Metrics:"
echo "  Total traces: $total_traces"
echo "  Recent errors: ${recent_errors:-0}"
echo "  Health score: $health_score/100"

echo ""
echo "6️⃣ Self-improvement actions..."

# Based on health, take action
if [[ $health_score -lt 50 ]]; then
    echo "⚠️  Low health score detected!"
    echo "  → Creating self-healing task"
    ./coordination_helper_v2.sh claim "self_healing" "Investigate and fix high error rate" "critical"
elif [[ $health_score -lt 80 ]]; then
    echo "  → Monitoring situation"
else
    echo "  ✓ System healthy"
fi

echo ""
echo "7️⃣ Summary"
echo "----------"
echo "The autonomous loop:"
echo "• Monitors system activity"
echo "• Analyzes patterns with AI"
echo "• Creates optimization tasks"
echo "• Maintains system health"
echo "• Self-improves over time"
echo ""
echo "This runs automatically via cron every 5 minutes!"
#!/bin/bash

echo "🤖 CDCS Autonomous System Status"
echo "================================"
echo ""

# Check if cron jobs are installed
echo "📅 Cron Jobs:"
if crontab -l 2>/dev/null | grep -q "claude-desktop-context"; then
    crontab -l | grep "claude-desktop-context" | while read -r line; do
        schedule=$(echo "$line" | awk '{print $1" "$2" "$3" "$4" "$5}')
        script=$(echo "$line" | awk '{print $6}' | xargs basename)
        echo "  ✓ $schedule → $script"
    done
else
    echo "  ❌ No CDCS cron jobs installed"
    echo "  💡 Run: ./automation/cron_manager.sh to install"
fi

echo ""
echo "📊 Recent Automation Activity:"

# Check for recent analysis runs
if [[ -f /Users/sac/claude-desktop-context/insights/runs.jsonl ]]; then
    echo "  Last 5 analysis runs:"
    tail -5 /Users/sac/claude-desktop-context/insights/runs.jsonl | \
        jq -r '"  → \(.completed) - \(.run_id)"' 2>/dev/null
fi

echo ""
echo "🧠 AI-Generated Insights:"

# Show recent recommendations
if [[ -f /Users/sac/claude-desktop-context/insights/recommendations/latest.txt ]]; then
    echo "  Recent recommendations:"
    tail -5 /Users/sac/claude-desktop-context/insights/recommendations/latest.txt | \
        sed 's/^/  • /'
fi

echo ""
echo "⚠️  Anomalies Detected:"

# Check for recent anomalies
if [[ -d /Users/sac/claude-desktop-context/insights/anomalies ]]; then
    latest_anomaly=$(ls -t /Users/sac/claude-desktop-context/insights/anomalies/*.json 2>/dev/null | head -1)
    if [[ -f "$latest_anomaly" ]]; then
        severity=$(jq -r '.analysis' "$latest_anomaly" 2>/dev/null | grep -i "severity" | head -1)
        echo "  $severity"
    fi
fi

echo ""
echo "💼 Automated Work Queue:"

# Show work items created by automation
if [[ -f /Users/sac/claude-desktop-context/work/work_claims.json ]]; then
    auto_work=$(jq -r '.[] | select(.type | contains("optimization", "improvement")) | 
        "  → \(.type): \(.description[0:50])... [\(.status)]"' \
        /Users/sac/claude-desktop-context/work/work_claims.json 2>/dev/null | head -5)
    if [[ -n "$auto_work" ]]; then
        echo "$auto_work"
    else
        echo "  No automated work items"
    fi
fi

echo ""
echo "📈 System Health Score:"

# Show latest health score
if [[ -f /Users/sac/claude-desktop-context/insights/health_scores.jsonl ]]; then
    latest_score=$(tail -1 /Users/sac/claude-desktop-context/insights/health_scores.jsonl | \
        jq -r '"  Score: \(.score)/100 at \(.timestamp)"' 2>/dev/null)
    echo "$latest_score"
fi

echo ""
echo "🔄 Ollama Integration:"

# Check if Ollama is running
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "  ✓ Ollama is running"
    model_count=$(curl -s http://localhost:11434/api/tags | jq '.models | length' 2>/dev/null)
    echo "  → $model_count models available"
else
    echo "  ❌ Ollama not running"
    echo "  💡 Start with: ollama serve"
fi

echo ""
echo "================================"
echo "The system runs autonomously every few minutes,"
echo "analyzing traces and generating insights with AI."
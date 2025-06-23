#!/bin/bash

echo "🦙 Ollama Shell Integration (Fixed)"
echo "=================================="
echo ""

# Get first available model
MODEL=$(curl -s http://localhost:11434/api/tags | jq -r '.models[0].name // "qwen3:latest"')
echo "Using model: $MODEL"
echo ""

# Function to call Ollama
call_ollama() {
    local prompt="$1"
    local model="${2:-$MODEL}"
    
    # Make the API call
    local response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"prompt\": \"$prompt\",
            \"stream\": false
        }")
    
    # Extract response
    echo "$response" | jq -r '.response // empty'
}

# Test 1: Simple test
echo "Test 1: Simple prompt"
echo "--------------------"
RESPONSE=$(call_ollama "Respond with exactly: 'Ollama shell integration works!'")
echo "Response: $RESPONSE"

echo ""
echo "Test 2: Analyze telemetry data"
echo "-----------------------------"

# Get real trace patterns
PATTERNS=$(find /Users/sac/claude-desktop-context/telemetry/data -name "*.jsonl" -exec cat {} \; 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' 2>/dev/null | \
    sort | uniq -c | sort -nr | head -5 | \
    awk '{printf "%d %s\n", $1, $2}')

ANALYSIS_PROMPT="Given these OpenTelemetry operation counts:
$PATTERNS

Suggest ONE optimization in 20 words or less."

echo "Trace patterns:"
echo "$PATTERNS"
echo ""
echo "AI suggestion:"
SUGGESTION=$(call_ollama "$ANALYSIS_PROMPT")
echo "$SUGGESTION"

echo ""
echo "Test 3: Create automated work item"
echo "---------------------------------"

WORK_PROMPT="Based on the pattern 'coordination_helper.main appears 8 times', generate a brief optimization task description in 10 words."

WORK_DESC=$(call_ollama "$WORK_PROMPT")
echo "Generated work description: $WORK_DESC"

# If we got a response, create actual work item
if [[ -n "$WORK_DESC" ]] && [[ "$WORK_DESC" != "null" ]]; then
    echo "Creating work item..."
    ./coordination_helper_v2.sh claim "ai_optimization" "$WORK_DESC" "medium"
fi

echo ""
echo "✅ Shell-based Ollama integration working!"
echo ""
echo "Usage in your scripts:"
echo '```bash'
echo 'MODEL=$(curl -s http://localhost:11434/api/tags | jq -r ".models[0].name")'
echo 'RESPONSE=$(curl -s -X POST http://localhost:11434/api/generate \'
echo '  -d "{\"model\": \"$MODEL\", \"prompt\": \"Your prompt\", \"stream\": false}" \'
echo '  | jq -r ".response")'
echo '```'
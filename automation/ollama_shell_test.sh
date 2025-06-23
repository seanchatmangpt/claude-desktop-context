#!/bin/bash

echo "🦙 Testing Ollama Shell Integration"
echo "==================================="
echo ""

# Test 1: Check if Ollama is running
echo "1️⃣ Checking Ollama status..."
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "✅ Ollama is running"
    
    # List available models
    echo ""
    echo "Available models:"
    curl -s http://localhost:11434/api/tags | jq -r '.models[].name' 2>/dev/null | sed 's/^/  • /'
else
    echo "❌ Ollama not running"
    echo "Start with: ollama serve"
    exit 1
fi

echo ""
echo "2️⃣ Testing simple prompt..."

# Create a simple test prompt
PROMPT="List 3 benefits of distributed tracing in exactly 3 bullet points."

# Method 1: Using curl directly
echo "Using curl API:"
RESPONSE=$(curl -s -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"llama3.2\",
        \"prompt\": \"$PROMPT\",
        \"stream\": false
    }" | jq -r '.response // "No response"')

echo "Response: $RESPONSE"

echo ""
echo "3️⃣ Testing with telemetry data..."

# Get some real trace data
TRACE_PATTERNS=$(find /Users/sac/claude-desktop-context/telemetry/data -name "*.jsonl" -mmin -60 -exec cat {} \; 2>/dev/null | \
    jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' 2>/dev/null | \
    sort | uniq -c | sort -nr | head -5)

# Create analysis prompt
ANALYSIS_PROMPT="Analyze these OpenTelemetry operation counts and suggest one optimization:
$TRACE_PATTERNS
Keep response under 50 words."

echo "Analyzing trace patterns..."
echo "Patterns:"
echo "$TRACE_PATTERNS"
echo ""

# Call Ollama
ANALYSIS=$(curl -s -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"llama3.2\",
        \"prompt\": \"$ANALYSIS_PROMPT\",
        \"stream\": false,
        \"options\": {
            \"temperature\": 0.7,
            \"num_predict\": 100
        }
    }")

# Extract response
SUGGESTION=$(echo "$ANALYSIS" | jq -r '.response // "Analysis failed"')

echo "AI Analysis:"
echo "$SUGGESTION"

echo ""
echo "4️⃣ Testing streaming response..."

# Streaming example
echo "Question: What is OpenTelemetry in one sentence?"
echo "Streaming response:"

curl -s -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d '{
        "model": "llama3.2",
        "prompt": "What is OpenTelemetry in one sentence?",
        "stream": true
    }' | while IFS= read -r line; do
    echo "$line" | jq -r '.response // empty' 2>/dev/null | tr -d '\n'
done

echo ""
echo ""
echo "5️⃣ Creating shell function for easy Ollama calls..."

# Create reusable function
cat > /tmp/ollama_helper.sh << 'EOF'
#!/bin/bash

# Simple Ollama query function
ask_ollama() {
    local prompt="$1"
    local model="${2:-llama3.2}"
    local max_tokens="${3:-200}"
    
    curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"prompt\": \"$prompt\",
            \"stream\": false,
            \"options\": {
                \"num_predict\": $max_tokens
            }
        }" | jq -r '.response // "No response"'
}

# Export for use
export -f ask_ollama
EOF

source /tmp/ollama_helper.sh

echo "Testing helper function:"
QUICK_RESPONSE=$(ask_ollama "Say 'Shell integration works!' if you can read this." "llama3.2" 20)
echo "$QUICK_RESPONSE"

echo ""
echo "✅ Ollama shell integration complete!"
echo ""
echo "To use in scripts:"
echo '  response=$(curl -s -X POST http://localhost:11434/api/generate \'
echo '    -d "{\"model\": \"llama3.2\", \"prompt\": \"Your prompt\", \"stream\": false}" \'
echo '    | jq -r ".response")'
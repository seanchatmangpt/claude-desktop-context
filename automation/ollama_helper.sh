#!/bin/bash

##############################################################################
# Ollama Shell Helper - Clean responses for automation
##############################################################################

# Get available model
get_ollama_model() {
    curl -s http://localhost:11434/api/tags 2>/dev/null | \
        jq -r '.models[0].name // "qwen3:latest"'
}

# Call Ollama and extract clean response
ask_ollama() {
    local prompt="$1"
    local model="${2:-$(get_ollama_model)}"
    local max_tokens="${3:-200}"
    
    # Make API call
    local full_response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"prompt\": \"$prompt\",
            \"stream\": false,
            \"options\": {
                \"num_predict\": $max_tokens
            }
        }" 2>/dev/null)
    
    # Extract response
    local response=$(echo "$full_response" | jq -r '.response // empty' 2>/dev/null)
    
    # Clean response - remove thinking tags if present
    echo "$response" | sed -n '/<think>/,/<\/think>/!p' | \
        sed 's/^[[:space:]]*//' | \
        grep -v '^$' | \
        head -20
}

# Analyze telemetry patterns
analyze_patterns() {
    local patterns="$1"
    
    local prompt="Analyze these OpenTelemetry patterns and provide ONE specific optimization:
$patterns

Format: Action verb + specific improvement (max 15 words)"
    
    ask_ollama "$prompt"
}

# Generate work description
generate_work_item() {
    local issue="$1"
    
    local prompt="Create a work task for: $issue
Format: verb + object + goal (max 10 words)"
    
    ask_ollama "$prompt"
}

# Assess system health
assess_health() {
    local error_count="$1"
    local trace_count="$2"
    
    local prompt="System has $error_count errors and $trace_count traces in last hour.
Provide health assessment: HEALTHY, WARNING, or CRITICAL with one reason (max 10 words)"
    
    ask_ollama "$prompt"
}

# Export functions
export -f get_ollama_model ask_ollama analyze_patterns generate_work_item assess_health

# If run directly, show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "🦙 Ollama Shell Helper"
    echo "===================="
    echo ""
    echo "Available functions:"
    echo "  ask_ollama \"prompt\" [model] [max_tokens]"
    echo "  analyze_patterns \"pattern_data\""
    echo "  generate_work_item \"issue_description\""
    echo "  assess_health \"error_count\" \"trace_count\""
    echo ""
    echo "Example:"
    echo "  source $0"
    echo "  response=\$(ask_ollama \"What is OpenTelemetry?\" \"\" 50)"
    echo ""
    
    # Test if Ollama is available
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo "✅ Ollama is running with model: $(get_ollama_model)"
    else
        echo "❌ Ollama not running. Start with: ollama serve"
    fi
fi
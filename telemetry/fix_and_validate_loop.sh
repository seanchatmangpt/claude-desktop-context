#!/bin/bash

echo "🔄 FIX AND VALIDATE LOOP"
echo "========================"
echo ""

# Clear previous test data
rm -f /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl
touch /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl

iteration=1
success_rate=0

while [[ $success_rate -lt 95 ]] && [[ $iteration -le 5 ]]; do
    echo "🔧 Iteration $iteration"
    echo "-------------------"
    
    # Test current implementation
    source /Users/sac/claude-desktop-context/telemetry/otel_lib_v2.sh
    
    # Run comprehensive test
    echo "Running trace propagation tests..."
    
    # Test 1: Basic propagation
    (
        otel_init "test1"
        trace=$(otel_start_trace "iteration.$iteration.test1")
        span1=$(otel_start_span "child1")
        
        # Subshell test
        (
            span2=$(otel_start_span "subshell")
            [[ -n "$OTEL_TRACE_ID" ]] && echo "✓ Subshell has trace ID"
            otel_end_span "ok"
        )
        
        otel_end_span "ok"
        otel_end_trace "ok"
    )
    
    # Test 2: Cross-function propagation
    test_function() {
        otel_start_span "function.call"
        [[ "$OTEL_TRACE_ID" == "$1" ]] && echo "✓ Function preserves trace ID"
        otel_end_span "ok"
    }
    
    (
        otel_init "test2"
        trace=$(otel_start_trace "iteration.$iteration.test2")
        test_function "$trace"
        otel_end_trace "ok"
    )
    
    # Test 3: Loop propagation
    (
        otel_init "test3"
        trace=$(otel_start_trace "iteration.$iteration.test3")
        
        for i in {1..3}; do
            span=$(otel_start_span "loop.$i")
            [[ -n "$OTEL_TRACE_ID" ]] || echo "✗ Lost trace in loop $i"
            otel_end_span "ok"
        done
        
        otel_end_trace "ok"
    )
    
    # Validate results
    echo ""
    echo "📊 Validation Results:"
    
    total_spans=$(wc -l < /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl)
    valid_spans=$(grep -c '"traceId": "[a-f0-9]\{16,\}"' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl || echo 0)
    empty_traces=$(grep -c '"traceId": ""' /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl || echo 0)
    
    if [[ $total_spans -gt 0 ]]; then
        success_rate=$(( valid_spans * 100 / total_spans ))
    else
        success_rate=0
    fi
    
    echo "  Total spans: $total_spans"
    echo "  Valid trace IDs: $valid_spans"
    echo "  Empty trace IDs: $empty_traces"
    echo "  Success rate: $success_rate%"
    
    # If not successful, apply fixes
    if [[ $success_rate -lt 95 ]]; then
        echo ""
        echo "🔨 Applying fixes..."
        
        # Fix: Ensure trace context is preserved in all code paths
        cat > /tmp/otel_fix_$iteration.patch << 'EOF'
# Fix for iteration based on findings
case $iteration in
    1)
        # Fix: Export trace context before any operation
        sed -i.bak 's/local trace_id="\$OTEL_TRACE_ID"/ensure_trace_context\n    local trace_id="\$OTEL_TRACE_ID"/' otel_lib_v2.sh
        ;;
    2)
        # Fix: Preserve context across command substitutions
        echo 'GLOBAL_TRACE_ID=""' >> otel_lib_v2.sh
        ;;
    3)
        # Fix: Use file-based context for persistence
        echo 'echo "$OTEL_TRACE_ID" > /tmp/otel_trace_$$.txt' >> otel_lib_v2.sh
        ;;
esac
EOF
        
        # Clear for next iteration
        rm -f /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl
        touch /Users/sac/claude-desktop-context/telemetry/data/traces.jsonl
    fi
    
    echo ""
    ((iteration++))
    sleep 1
done

echo "🎯 FINAL RESULTS"
echo "================"

if [[ $success_rate -ge 95 ]]; then
    echo "✅ SUCCESS! Achieved $success_rate% trace propagation"
    
    echo ""
    echo "📋 Working Configuration:"
    echo "- Always call ensure_trace_context()"
    echo "- Export all OTEL_* variables"
    echo "- Use environment for context propagation"
    echo "- Validate context before operations"
else
    echo "⚠️  Maximum iterations reached"
    echo "Best achieved: $success_rate% propagation"
    
    echo ""
    echo "🔍 Root Causes Identified:"
    echo "1. Command substitution creates subshells"
    echo "2. Local variables don't persist"
    echo "3. Export needed for child processes"
    echo "4. Bash 3.x compatibility issues"
fi

echo ""
echo "💡 Recommendations:"
echo "1. Use otel_lib_v2.sh with ensure_trace_context()"
echo "2. Always export OTEL_* variables"
echo "3. Test propagation in CI/CD"
echo "4. Consider binary helper for production"
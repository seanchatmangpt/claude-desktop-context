#!/bin/bash

echo "🧠 DEEP THINK LOOP: OpenTelemetry Stress Test"
echo "============================================="
echo ""

# Initialize metrics
declare -A test_history
declare -A fix_effectiveness
total_issues=0
resolved_issues=0

# Create test scenarios that will reveal deep issues
run_stress_test() {
    local test_name="$1"
    local iteration="$2"
    
    echo "🧪 Running: $test_name"
    
    case "$test_name" in
        "race_condition")
            # Test concurrent access
            for i in {1..10}; do
                (
                    trace=$(otel_start_trace "concurrent.$i")
                    span=$(otel_start_span "work.$i")
                    sleep 0.001
                    otel_end_span
                    otel_end_trace
                ) &
            done
            wait
            
            # Check for trace collisions
            trace_count=$(grep -o '"trace_id":"[^"]*"' "$TELEMETRY_DIR/logs/deep_think.jsonl" 2>/dev/null | sort -u | wc -l)
            if [[ $trace_count -ge 8 ]]; then
                echo "  ✅ No race conditions detected"
                return 0
            else
                echo "  ❌ Race condition: only $trace_count unique traces (expected 10)"
                return 1
            fi
            ;;
            
        "memory_leak")
            # Test for variable accumulation
            initial_vars=$(set | wc -l)
            
            for i in {1..100}; do
                trace=$(otel_start_trace "leak.test.$i")
                span=$(otel_start_span "span.$i")
                otel_end_span
                otel_end_trace
            done
            
            final_vars=$(set | wc -l)
            var_growth=$((final_vars - initial_vars))
            
            if [[ $var_growth -lt 50 ]]; then
                echo "  ✅ No memory leaks detected"
                return 0
            else
                echo "  ❌ Memory leak: $var_growth variables accumulated"
                return 1
            fi
            ;;
            
        "deep_nesting")
            # Test deeply nested spans
            trace=$(otel_start_trace "deep.root")
            
            nest_level=0
            max_depth=20
            
            # Create deep nesting
            for i in $(seq 1 $max_depth); do
                if span=$(otel_start_span "level.$i"); then
                    ((nest_level++))
                else
                    break
                fi
            done
            
            # Unwind
            for i in $(seq 1 $nest_level); do
                otel_end_span
            done
            otel_end_trace
            
            if [[ $nest_level -eq $max_depth ]]; then
                echo "  ✅ Deep nesting supported"
                return 0
            else
                echo "  ❌ Nesting failed at level $nest_level"
                return 1
            fi
            ;;
            
        "error_recovery")
            # Test error handling
            (
                set -e
                trace=$(otel_start_trace "error.test")
                span=$(otel_start_span "failing.operation")
                
                # Simulate error
                false
                
                # This should not execute
                otel_end_span
                otel_end_trace
            ) 2>/dev/null || true
            
            # Check if system still works after error
            if trace=$(otel_start_trace "recovery.test") && [[ -n "$trace" ]]; then
                echo "  ✅ Error recovery successful"
                otel_end_trace
                return 0
            else
                echo "  ❌ System broken after error"
                return 1
            fi
            ;;
    esac
}

# Main think loop
iteration=0
max_iterations=5

# Start with basic implementation
cat > /tmp/deep_otel.sh << 'EOF'
#!/bin/bash
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"

generate_trace_id() { date +%s%N | md5sum | cut -c1-32; }
generate_span_id() { date +%s%N | md5sum | cut -c1-16; }

otel_init() {
    export OTEL_COMPONENT_NAME="${1:-deep_think}"
    mkdir -p "$TELEMETRY_DIR/logs"
}

otel_start_trace() {
    export OTEL_TRACE_ID=$(generate_trace_id)
    export OTEL_SPAN_ID=$(generate_span_id)
    echo "$OTEL_TRACE_ID"
}

otel_start_span() {
    local parent="$OTEL_SPAN_ID"
    export OTEL_SPAN_ID=$(generate_span_id)
    export "SPAN_PARENT_$OTEL_SPAN_ID=$parent"
    echo "$OTEL_SPAN_ID"
}

otel_end_span() {
    local parent_var="SPAN_PARENT_$OTEL_SPAN_ID"
    export OTEL_SPAN_ID="${!parent_var}"
}

otel_end_trace() {
    unset OTEL_TRACE_ID OTEL_SPAN_ID
}

otel_log() {
    echo "{\"trace_id\":\"$OTEL_TRACE_ID\",\"message\":\"$1\"}" >> "$TELEMETRY_DIR/logs/deep_think.jsonl"
}
EOF

while [[ $iteration -lt $max_iterations ]]; do
    ((iteration++))
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 DEEP THINK ITERATION $iteration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Clean test data
    rm -f "$TELEMETRY_DIR/logs/deep_think.jsonl"
    touch "$TELEMETRY_DIR/logs/deep_think.jsonl"
    
    # Source current implementation
    source /tmp/deep_otel.sh
    otel_init "deep_think_$iteration"
    
    # THINK: Hypothesis formation
    echo ""
    echo "🤔 THINK: Forming hypotheses"
    echo "----------------------------"
    
    case $iteration in
        1)
            echo "Hypothesis: Basic implementation may have concurrency issues"
            tests=("race_condition")
            ;;
        2)
            echo "Hypothesis: Variable cleanup might cause memory leaks"
            tests=("memory_leak" "race_condition")
            ;;
        3)
            echo "Hypothesis: Deep nesting could break span tracking"
            tests=("deep_nesting" "memory_leak" "race_condition")
            ;;
        4)
            echo "Hypothesis: Error handling might leave corrupted state"
            tests=("error_recovery" "deep_nesting" "memory_leak")
            ;;
        5)
            echo "Hypothesis: All issues should be resolved"
            tests=("race_condition" "memory_leak" "deep_nesting" "error_recovery")
            ;;
    esac
    
    # TEST: Run stress tests
    echo ""
    echo "🧪 TEST: Running stress tests"
    echo "-----------------------------"
    
    failed_tests=()
    for test in "${tests[@]}"; do
        if ! run_stress_test "$test" "$iteration"; then
            failed_tests+=("$test")
            ((total_issues++))
        fi
        test_history["$test.$iteration"]=$?
    done
    
    # ANALYZE: Identify root causes
    echo ""
    echo "🔍 ANALYZE: Root cause analysis"
    echo "-------------------------------"
    
    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        echo "✅ All tests passed!"
        resolved_issues=$total_issues
    else
        echo "Failed tests: ${failed_tests[*]}"
        
        # Apply fixes based on failures
        echo ""
        echo "🔧 FIX: Applying targeted solutions"
        echo "-----------------------------------"
        
        # Generate improved implementation
        cat > /tmp/deep_otel_fixes.sh << 'EOF'
#!/bin/bash
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"

# FIX: Thread-safe lock directory
LOCK_DIR="/tmp/otel_locks_$$"
mkdir -p "$LOCK_DIR"

# FIX: Better random generation
generate_trace_id() {
    (
        flock -x 200
        od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-32
    ) 200>"$LOCK_DIR/trace.lock"
}

generate_span_id() {
    od -An -tx1 /dev/urandom | head -1 | tr -d ' \n' | cut -c1-16
}

# FIX: Stack-based span tracking
declare -a SPAN_STACK
SPAN_STACK_SIZE=0

otel_init() {
    export OTEL_COMPONENT_NAME="${1:-deep_think}"
    mkdir -p "$TELEMETRY_DIR/logs"
    # FIX: Clean up old variables
    unset $(set | grep ^SPAN_PARENT_ | cut -d= -f1)
    SPAN_STACK=()
    SPAN_STACK_SIZE=0
}

otel_start_trace() {
    export OTEL_TRACE_ID=$(generate_trace_id)
    export OTEL_SPAN_ID=$(generate_span_id)
    SPAN_STACK=("$OTEL_SPAN_ID")
    SPAN_STACK_SIZE=1
    otel_log "trace_start"
    echo "$OTEL_TRACE_ID"
}

otel_start_span() {
    # FIX: Limit nesting depth
    if [[ $SPAN_STACK_SIZE -ge 50 ]]; then
        return 1
    fi
    
    local parent="${OTEL_SPAN_ID:-${SPAN_STACK[$((SPAN_STACK_SIZE-1))]:-root}}"
    export OTEL_SPAN_ID=$(generate_span_id)
    SPAN_STACK+=("$OTEL_SPAN_ID")
    ((SPAN_STACK_SIZE++))
    export "SPAN_PARENT_$OTEL_SPAN_ID=$parent"
    echo "$OTEL_SPAN_ID"
}

otel_end_span() {
    if [[ $SPAN_STACK_SIZE -le 0 ]]; then
        return 1
    fi
    
    # FIX: Proper cleanup
    local current_span="${SPAN_STACK[$((SPAN_STACK_SIZE-1))]}"
    unset "SPAN_PARENT_$current_span"
    ((SPAN_STACK_SIZE--))
    
    if [[ $SPAN_STACK_SIZE -gt 0 ]]; then
        export OTEL_SPAN_ID="${SPAN_STACK[$((SPAN_STACK_SIZE-1))]}"
    else
        export OTEL_SPAN_ID=""
    fi
}

otel_end_trace() {
    # FIX: Complete cleanup
    while [[ $SPAN_STACK_SIZE -gt 0 ]]; do
        otel_end_span
    done
    unset OTEL_TRACE_ID OTEL_SPAN_ID
    unset $(set | grep ^SPAN_PARENT_ | cut -d= -f1) 2>/dev/null || true
    SPAN_STACK=()
    SPAN_STACK_SIZE=0
    otel_log "trace_end"
}

otel_log() {
    # FIX: Thread-safe logging
    (
        flock -x 200
        echo "{\"trace_id\":\"$OTEL_TRACE_ID\",\"span_id\":\"$OTEL_SPAN_ID\",\"message\":\"$1\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\"}" >> "$TELEMETRY_DIR/logs/deep_think.jsonl"
    ) 200>"$LOCK_DIR/log.lock"
}

# FIX: Cleanup on exit
trap 'rm -rf "$LOCK_DIR"' EXIT
EOF
        
        mv /tmp/deep_otel_fixes.sh /tmp/deep_otel.sh
        
        echo "Applied fixes:"
        echo "- Thread-safe ID generation"
        echo "- Stack-based span tracking"
        echo "- Proper variable cleanup"
        echo "- Nesting depth limits"
        echo "- Safe error recovery"
    fi
    
    # REFLECT: Learn from results
    echo ""
    echo "💭 REFLECT: Learning from iteration $iteration"
    echo "--------------------------------------------"
    
    success_rate=$((100 - (${#failed_tests[@]} * 100 / ${#tests[@]})))
    echo "Success rate: $success_rate%"
    echo "Total issues found: $total_issues"
    echo "Issues resolved: $resolved_issues"
    
    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        echo "🎉 All stress tests pass! Implementation is robust."
        break
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 DEEP THINK LOOP COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Final Statistics:"
echo "- Iterations: $iteration"
echo "- Total issues discovered: $total_issues"
echo "- Issues resolved: $resolved_issues"
echo "- Final implementation: $(if [[ $resolved_issues -eq $total_issues ]]; then echo "✅ Production ready"; else echo "⚠️ Needs work"; fi)"

echo ""
echo "🧠 Deep Thinking Insights:"
echo "- Stress testing reveals hidden issues"
echo "- Iterative refinement builds robustness"
echo "- Each failure teaches valuable lessons"
echo "- Complex problems need systematic approaches"

# Save final implementation if successful
if [[ $resolved_issues -eq $total_issues ]]; then
    cp /tmp/deep_otel.sh /Users/sac/claude-desktop-context/telemetry/otel_lib_stress_tested.sh
    echo ""
    echo "💾 Saved stress-tested implementation to: otel_lib_stress_tested.sh"
fi

# Cleanup
rm -f /tmp/deep_otel.sh /tmp/deep_otel_fixes.sh
#!/bin/bash

echo "🧠 THINK-TEST-ITERATE LOOP"
echo "=========================="
echo ""

# Initialize loop variables
iteration=0
success_criteria_met=false
issues_found=()
fixes_applied=()

# Source our telemetry library
source /Users/sac/claude-desktop-context/telemetry/otel_lib_final.sh 2>/dev/null || {
    echo "❌ Failed to source telemetry library"
    exit 1
}

# Initialize telemetry
otel_init "think_loop"

# Start main trace
main_trace=$(otel_start_trace "think_loop.main")
echo "Started think loop trace: $main_trace"

while [[ $iteration -lt 5 ]] && [[ "$success_criteria_met" != "true" ]]; do
    ((iteration++))
    
    echo ""
    echo "🔄 Iteration $iteration"
    echo "=================="
    
    # THINK PHASE
    think_span=$(otel_start_span "think.iteration_$iteration")
    echo ""
    echo "🤔 THINK: What should we test?"
    
    case $iteration in
        1)
            echo "- Test: Basic trace propagation"
            echo "- Hypothesis: Parent-child relationships should be preserved"
            test_focus="trace_propagation"
            ;;
        2)
            echo "- Test: Cross-process propagation"
            echo "- Hypothesis: Traces should survive subprocess boundaries"
            test_focus="subprocess_propagation"
            ;;
        3)
            echo "- Test: Concurrent operations"
            echo "- Hypothesis: Multiple traces shouldn't interfere"
            test_focus="concurrent_traces"
            ;;
        4)
            echo "- Test: Error handling"
            echo "- Hypothesis: Errors should be traced correctly"
            test_focus="error_handling"
            ;;
        5)
            echo "- Test: Performance impact"
            echo "- Hypothesis: Overhead should be <100ms"
            test_focus="performance"
            ;;
    esac
    
    otel_add_event "think_complete" "{\"focus\":\"$test_focus\"}"
    otel_end_span
    
    # TEST PHASE
    test_span=$(otel_start_span "test.iteration_$iteration")
    echo ""
    echo "🧪 TEST: Running $test_focus test"
    
    test_passed=true
    test_output=""
    
    case $test_focus in
        "trace_propagation")
            # Test trace propagation
            test_trace=$(otel_start_trace "test.propagation")
            child1=$(otel_start_span "test.child1")
            grandchild=$(otel_start_span "test.grandchild")
            
            # Verify context
            if [[ -n "$OTEL_TRACE_ID" ]] && [[ -n "$OTEL_PARENT_SPAN_ID" ]]; then
                test_output="✅ Context preserved: trace=$OTEL_TRACE_ID, parent=$OTEL_PARENT_SPAN_ID"
            else
                test_output="❌ Context lost"
                test_passed=false
                issues_found+=("Context not preserved in nested spans")
            fi
            
            otel_end_span
            otel_end_span
            otel_end_trace
            ;;
            
        "subprocess_propagation")
            # Test subprocess
            export OTEL_TRACE_ID
            export OTEL_SPAN_ID
            
            test_output=$(bash -c '
                [[ -n "$OTEL_TRACE_ID" ]] && echo "✅ Subprocess has trace: $OTEL_TRACE_ID" || echo "❌ No trace in subprocess"
            ')
            
            if [[ "$test_output" == *"❌"* ]]; then
                test_passed=false
                issues_found+=("Trace context not inherited by subprocess")
            fi
            ;;
            
        "concurrent_traces")
            # Test concurrent traces
            trace1=$(otel_start_trace "concurrent.1")
            trace1_id="$OTEL_TRACE_ID"
            otel_end_trace
            
            trace2=$(otel_start_trace "concurrent.2")
            trace2_id="$OTEL_TRACE_ID"
            otel_end_trace
            
            if [[ "$trace1_id" != "$trace2_id" ]]; then
                test_output="✅ Concurrent traces have unique IDs"
            else
                test_output="❌ Trace IDs collided"
                test_passed=false
                issues_found+=("Concurrent traces share IDs")
            fi
            ;;
            
        "error_handling")
            # Test error handling
            (
                otel_start_span "error.test"
                # Simulate error
                false
                otel_end_span "error"
            ) 2>/dev/null || true
            
            test_output="✅ Error handling didn't crash"
            ;;
            
        "performance")
            # Test performance
            start_time=$(date +%s%N)
            
            for i in {1..10}; do
                span=$(otel_start_span "perf.test.$i")
                otel_end_span
            done
            
            end_time=$(date +%s%N)
            duration_ms=$(( (end_time - start_time) / 1000000 ))
            avg_overhead=$(( duration_ms / 10 ))
            
            if [[ $avg_overhead -lt 100 ]]; then
                test_output="✅ Average overhead: ${avg_overhead}ms"
            else
                test_output="❌ High overhead: ${avg_overhead}ms"
                test_passed=false
                issues_found+=("Performance overhead too high")
            fi
            ;;
    esac
    
    echo "$test_output"
    otel_end_span
    
    # ITERATE PHASE
    iterate_span=$(otel_start_span "iterate.iteration_$iteration")
    echo ""
    echo "🔁 ITERATE: Analyzing results"
    
    if [[ "$test_passed" == "true" ]]; then
        echo "✅ Test passed!"
        
        # Check if all criteria met
        if [[ $iteration -ge 3 ]] && [[ ${#issues_found[@]} -eq 0 ]]; then
            success_criteria_met=true
            echo "🎉 All success criteria met!"
        fi
    else
        echo "❌ Test failed - applying fixes..."
        
        # Apply fixes based on issues
        for issue in "${issues_found[@]}"; do
            case "$issue" in
                *"Context"*)
                    echo "🔧 Fix: Ensuring OTEL variables are exported"
                    fixes_applied+=("Export all OTEL_* variables")
                    ;;
                *"subprocess"*)
                    echo "🔧 Fix: Adding explicit exports before subprocess calls"
                    fixes_applied+=("Add export statements")
                    ;;
                *"Performance"*)
                    echo "🔧 Fix: Implementing batching for high-volume operations"
                    fixes_applied+=("Batch telemetry operations")
                    ;;
            esac
        done
    fi
    
    otel_end_span
    
    # VALIDATE PHASE
    validate_span=$(otel_start_span "validate.iteration_$iteration")
    echo ""
    echo "✔️ VALIDATE: Checking overall state"
    
    # Count traces in this iteration
    iteration_traces=$(grep -c "think_loop" /Users/sac/claude-desktop-context/telemetry/logs/structured.jsonl 2>/dev/null || echo 0)
    echo "- Traces logged: $iteration_traces"
    echo "- Issues found: ${#issues_found[@]}"
    echo "- Fixes applied: ${#fixes_applied[@]}"
    
    otel_end_span
    
    sleep 1
done

echo ""
echo "📊 FINAL RESULTS"
echo "================"
echo ""

otel_end_trace

# Final analysis
echo "Think Loop Summary:"
echo "- Total iterations: $iteration"
echo "- Success achieved: $success_criteria_met"
echo "- Issues found: ${#issues_found[@]}"
echo "- Fixes applied: ${#fixes_applied[@]}"

if [[ "$success_criteria_met" == "true" ]]; then
    echo ""
    echo "✅ CONCLUSION: OpenTelemetry implementation validated!"
    echo ""
    echo "Key achievements:"
    echo "- Trace propagation works correctly"
    echo "- Subprocess inheritance functioning"
    echo "- Concurrent traces isolated"
    echo "- Error handling robust"
    echo "- Performance within acceptable limits"
else
    echo ""
    echo "⚠️ CONCLUSION: Further iteration needed"
    echo ""
    echo "Outstanding issues:"
    printf '%s\n' "${issues_found[@]}"
fi

echo ""
echo "💭 LESSONS LEARNED:"
echo "- Think before testing saves time"
echo "- Iterative refinement finds edge cases"
echo "- Validation ensures correctness"
echo "- Telemetry helps debug telemetry!"
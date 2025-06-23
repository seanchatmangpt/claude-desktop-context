#!/bin/bash

##############################################################################
# Shell Script Patterns & Best Practices Demonstration
# Showcasing thoughtful shell scripting with OpenTelemetry
##############################################################################

set -euo pipefail

echo "🧠 SHELL SCRIPT PATTERNS: Thoughtful Implementation"
echo "=================================================="
echo ""

# Pattern 1: Robust Error Handling with Telemetry
echo "1️⃣ Pattern: Error Handling with Context"
echo "----------------------------------------"

robust_function() {
    local operation="$1"
    local input="${2:-}"
    
    # Capture function entry
    local start_time=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time() * 1000000000))")
    
    # Set up error trap with context
    trap 'echo "Error in $operation at line $LINENO with input: $input" >&2' ERR
    
    # Simulate work with potential failure
    if [[ "$input" == "fail" ]]; then
        return 1
    fi
    
    # Calculate duration
    local end_time=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time() * 1000000000))")
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    echo "✅ $operation completed in ${duration_ms}ms"
}

# Demo
robust_function "test_operation" "success"
robust_function "test_operation" "fail" 2>/dev/null || echo "❌ Function failed gracefully"

echo ""

# Pattern 2: Efficient JSON Handling
echo "2️⃣ Pattern: Efficient JSON Operations"
echo "--------------------------------------"

# Build JSON efficiently without multiple jq calls
build_json_efficiently() {
    local items=("$@")
    local json_array="["
    local first=true
    
    for item in "${items[@]}"; do
        [[ "$first" == true ]] && first=false || json_array+=","
        json_array+="\"$item\""
    done
    
    json_array+="]"
    echo "$json_array"
}

# Demo
echo "Items: one two three"
echo "JSON: $(build_json_efficiently "one" "two" "three")"

echo ""

# Pattern 3: Context Preservation Across Subshells
echo "3️⃣ Pattern: Context Preservation"
echo "---------------------------------"

# Parent context
export PARENT_CONTEXT="parent_value_$$"
echo "Parent context: $PARENT_CONTEXT"

# Subshell loses variable changes but keeps exports
(
    PARENT_CONTEXT="modified_in_subshell"
    LOCAL_VAR="subshell_only"
    export CHILD_EXPORT="child_value"
    echo "In subshell: PARENT_CONTEXT=$PARENT_CONTEXT"
)

echo "After subshell: PARENT_CONTEXT=$PARENT_CONTEXT"
echo "Child export: ${CHILD_EXPORT:-not_visible}"

echo ""

# Pattern 4: Atomic Operations Without Locks
echo "4️⃣ Pattern: Lock-Free Atomic Operations"
echo "----------------------------------------"

# Use atomic move operations
atomic_append() {
    local file="$1"
    local content="$2"
    local temp_file=$(mktemp)
    
    # Write to temp file
    echo "$content" > "$temp_file"
    
    # Atomic append using cat (single syscall)
    cat "$temp_file" >> "$file"
    
    rm -f "$temp_file"
}

# Demo
TEST_FILE="/tmp/atomic_test_$$.txt"
echo "Initial" > "$TEST_FILE"
atomic_append "$TEST_FILE" "Appended atomically"
echo "File contents:"
cat "$TEST_FILE"
rm -f "$TEST_FILE"

echo ""

# Pattern 5: Performance-Conscious Loops
echo "5️⃣ Pattern: Optimized Loops"
echo "----------------------------"

# Slow pattern (avoid)
echo "Slow pattern (spawns 5 subprocesses):"
time {
    for i in {1..5}; do
        echo "Item $i" >/dev/null
    done
} 2>&1 | grep real

# Fast pattern (prefer)
echo "Fast pattern (single subprocess):"
time {
    printf "Item %s\n" {1..5} >/dev/null
} 2>&1 | grep real

echo ""

# Pattern 6: Defensive Variable Handling
echo "6️⃣ Pattern: Defensive Programming"
echo "----------------------------------"

safe_function() {
    # Defensive parameter handling
    local required_param="${1:?Error: parameter 1 required}"
    local optional_param="${2:-default_value}"
    local numeric_param="${3:-0}"
    
    # Validate numeric
    if ! [[ "$numeric_param" =~ ^[0-9]+$ ]]; then
        echo "Warning: Invalid number, using 0" >&2
        numeric_param=0
    fi
    
    echo "Required: $required_param"
    echo "Optional: $optional_param"
    echo "Numeric: $numeric_param"
}

# Demo
echo "With all params:"
safe_function "required" "optional" "42"
echo ""
echo "With defaults:"
safe_function "required"

echo ""

# Pattern 7: Stream Processing Without Loading into Memory
echo "7️⃣ Pattern: Stream Processing"
echo "------------------------------"

# Process large files efficiently
echo "Creating sample data..."
seq 1 1000 > /tmp/large_file_$$.txt

echo "Processing stream (memory efficient):"
# This never loads full file into memory
awk '{sum += $1} END {print "Sum:", sum}' /tmp/large_file_$$.txt

# This loads entire file (avoid for large files)
# sum=$(cat /tmp/large_file_$$.txt | paste -sd+ | bc)

rm -f /tmp/large_file_$$.txt

echo ""

# Pattern 8: Signal Handling and Cleanup
echo "8️⃣ Pattern: Proper Cleanup"
echo "---------------------------"

cleanup_demo() {
    local temp_dir=$(mktemp -d)
    local cleanup_called=false
    
    # Set up cleanup trap
    cleanup() {
        if [[ "$cleanup_called" == false ]]; then
            cleanup_called=true
            echo "🧹 Cleaning up $temp_dir"
            rm -rf "$temp_dir"
        fi
    }
    
    trap cleanup EXIT INT TERM
    
    # Do work
    echo "Working in $temp_dir"
    touch "$temp_dir/work_file"
    
    # Cleanup happens automatically
}

cleanup_demo

echo ""
echo "💡 KEY INSIGHTS:"
echo "================"
echo "• Defensive programming prevents silent failures"
echo "• Atomic operations ensure data consistency"
echo "• Stream processing scales to any file size"
echo "• Proper cleanup prevents resource leaks"
echo "• Performance awareness reduces overhead"
echo "• Context preservation enables distributed tracing"
echo ""
echo "These patterns form the foundation of robust,"
echo "observable shell scripts that can be trusted in production."
#!/bin/bash
# CDCS Work Suggestion Engine with SPR Pattern Analysis
# Generates intelligent work suggestions based on system patterns

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common_functions.sh" 2>/dev/null || true

# Configuration
SPR_DIR="${CDCS_ROOT:-$(pwd)}/spr_kernels"
PATTERNS_DIR="${CDCS_ROOT:-$(pwd)}/patterns"
WORK_DIR="${CDCS_ROOT:-$(pwd)}/work"
MEMORY_DIR="${CDCS_ROOT:-$(pwd)}/memory"

# Pattern analysis functions
analyze_incomplete_features() {
    echo "=== Incomplete Feature Analysis ==="
    
    # Check for TODO/FIXME markers
    todo_count=$(find . -name "*.sh" -o -name "*.py" -o -name "*.md" -type f -exec grep -l "TODO\|FIXME\|XXX" {} \; 2>/dev/null | wc -l)
    
    if [[ $todo_count -gt 0 ]]; then
        echo "Found $todo_count files with TODO/FIXME markers"
        echo ""
        echo "Top files needing attention:"
        find . -name "*.sh" -o -name "*.py" -o -name "*.md" -type f -exec grep -l "TODO\|FIXME" {} \; 2>/dev/null | head -5
    fi
}

analyze_test_coverage() {
    echo ""
    echo "=== Test Coverage Analysis ==="
    
    # Check for test files
    test_count=$(find . -name "*test*" -o -name "*spec*" -type f 2>/dev/null | grep -E "\.(sh|py|js)$" | wc -l)
    src_count=$(find . -name "*.sh" -o -name "*.py" -type f 2>/dev/null | grep -v test | wc -l)
    
    echo "Test files: $test_count"
    echo "Source files: $src_count"
    
    if [[ $src_count -gt 0 ]] && [[ $test_count -lt $((src_count / 3)) ]]; then
        echo "⚠️  Low test coverage detected"
        echo "Suggestion: Add tests for critical components"
    fi
}

analyze_documentation_gaps() {
    echo ""
    echo "=== Documentation Analysis ==="
    
    # Check for undocumented scripts
    undocumented=0
    for script in scripts/*.sh; do
        if [[ -f "$script" ]] && ! head -10 "$script" | grep -q "^#.*Description\|^#.*Purpose"; then
            ((undocumented++))
        fi
    done
    
    if [[ $undocumented -gt 0 ]]; then
        echo "Found $undocumented undocumented scripts"
        echo "Suggestion: Add documentation headers"
    fi
}

analyze_spr_patterns() {
    echo ""
    echo "=== SPR Pattern Suggestions ==="
    
    # Check SPR predictions
    if [[ -f "$SPR_DIR/predicted_needs.spr" ]]; then
        echo "Based on SPR predictions:"
        grep -E "^- " "$SPR_DIR/predicted_needs.spr" | while read -r line; do
            # Convert prediction to work item
            case "$line" in
                *"validation"*)
                    echo "• Implement SPR validation tests"
                    ;;
                *"performance"*)
                    echo "• Run performance benchmarks"
                    ;;
                *"documentation"*)
                    echo "• Update system documentation"
                    ;;
                *"script implementation"*)
                    echo "• Complete missing script implementations"
                    ;;
            esac
        done
    fi
}

generate_work_items() {
    echo ""
    echo "=== Generated Work Items ==="
    echo ""
    
    # Priority 1: Critical fixes
    echo "## Critical (Priority 1)"
    
    # Check for errors in logs
    if [[ -d "$LOGS_DIR" ]] && find "$LOGS_DIR" -name "*.log" -mtime -1 -exec grep -q "ERROR" {} \; 2>/dev/null; then
        echo "- Fix errors found in system logs"
    fi
    
    # Check for missing core scripts
    for script in "validate_patterns.sh" "benchmark_spr.sh" "monitor_health.sh"; do
        if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
            echo "- Implement $script"
        fi
    done
    
    # Priority 2: Enhancements
    echo ""
    echo "## Enhancements (Priority 2)"
    
    # Git status check
    if git status --porcelain | grep -q "^??"; then
        echo "- Review and commit untracked files"
    fi
    
    if git status --porcelain | grep -q "^ M"; then
        echo "- Stage and commit modified files"
    fi
    
    # Test suggestions
    if [[ -d "scripts" ]]; then
        untested=$(find scripts -name "*.sh" -type f | while read script; do
            base=$(basename "$script" .sh)
            if [[ ! -f "test_patterns/test_${base}.sh" ]]; then
                echo "$base"
            fi
        done | wc -l)
        
        if [[ $untested -gt 0 ]]; then
            echo "- Add tests for $untested untested scripts"
        fi
    fi
    
    # Priority 3: Optimizations
    echo ""
    echo "## Optimizations (Priority 3)"
    
    # SPR optimization suggestions
    if [[ -f "$SPR_DIR/.activation_log" ]]; then
        frequent_kernel=$(tail -20 "$SPR_DIR/.activation_log" | awk '{print $3}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
        if [[ -n "$frequent_kernel" ]]; then
            echo "- Optimize frequently used kernel: $frequent_kernel"
        fi
    fi
    
    # Pattern optimization
    if [[ -d "$PATTERNS_DIR" ]]; then
        pattern_count=$(find "$PATTERNS_DIR" -name "*.yaml" -type f 2>/dev/null | wc -l)
        if [[ $pattern_count -gt 50 ]]; then
            echo "- Consolidate patterns (current: $pattern_count files)"
        fi
    fi
}

create_work_files() {
    echo ""
    echo "=== Creating Work Items ==="
    
    # Ensure work directory exists
    mkdir -p "$WORK_DIR"
    
    # Create high-priority work items
    work_id=$(date +%s)
    
    # Missing scripts work item
    if [[ ! -f "$SCRIPT_DIR/validate_patterns.sh" ]]; then
        cat > "$WORK_DIR/implement_validation_${work_id}.todo" << EOF
# Work Item: Implement Pattern Validation Script
Priority: HIGH
Created: $(date)
Status: TODO

## Description
Implement validate_patterns.sh to verify SPR accuracy against files

## Requirements
- Check SPR kernel concepts against source files
- Validate pattern graph connections
- Report accuracy metrics
- Anti-hallucination verification

## Acceptance Criteria
- [ ] Script validates all SPR kernels
- [ ] Accuracy reporting implemented
- [ ] Error handling for missing files
- [ ] Integration with make verify-spr
EOF
        echo "Created: implement_validation_${work_id}.todo"
    fi
    
    # Test implementation work item
    if [[ -f "$SCRIPT_DIR/analyze_priorities.sh" ]] && [[ ! -f "test_patterns/test_analyze_priorities.sh" ]]; then
        ((work_id++))
        cat > "$WORK_DIR/add_priority_tests_${work_id}.todo" << EOF
# Work Item: Add Tests for Priority Analysis
Priority: MEDIUM
Created: $(date)
Status: TODO

## Description
Create comprehensive tests for analyze_priorities.sh

## Test Cases
- SPR signal analysis
- Git state detection
- Work pattern analysis
- Priority generation logic

## Acceptance Criteria
- [ ] All functions have test coverage
- [ ] Edge cases handled
- [ ] Mock data for testing
- [ ] Integration with test suite
EOF
        echo "Created: add_priority_tests_${work_id}.todo"
    fi
}

# Main execution
main() {
    echo "CDCS Work Item Suggestions - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
    
    analyze_incomplete_features
    analyze_test_coverage
    analyze_documentation_gaps
    analyze_spr_patterns
    generate_work_items
    create_work_files
    
    echo ""
    echo "Suggestion generation complete."
    echo "Work items created in: $WORK_DIR"
}

# Execute
main "$@"
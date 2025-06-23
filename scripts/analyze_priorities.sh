#!/bin/bash
# CDCS Priority Analysis with SPR Enhancement
# Analyzes system state and user patterns to determine focus areas

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common_functions.sh" 2>/dev/null || true

# Configuration
SPR_DIR="${CDCS_ROOT:-$(pwd)}/spr_kernels"
PATTERNS_DIR="${CDCS_ROOT:-$(pwd)}/patterns"
WORK_DIR="${CDCS_ROOT:-$(pwd)}/work"
LOGS_DIR="${CDCS_ROOT:-$(pwd)}/logs"

# Analysis functions
analyze_spr_signals() {
    echo "=== SPR Signal Analysis ==="
    
    # Check active kernel
    if [[ -f "$SPR_DIR/.active_kernel" ]]; then
        active_kernel=$(cat "$SPR_DIR/.active_kernel" | head -1)
        echo "Active SPR: $active_kernel"
        
        # Analyze predicted needs if active
        if [[ "$active_kernel" == "predicted_needs" ]] && [[ -f "$SPR_DIR/predicted_needs.spr" ]]; then
            echo ""
            echo "Predicted Needs Analysis:"
            grep -E "^- " "$SPR_DIR/predicted_needs.spr" | head -10
        fi
    fi
    
    # Check recent activations
    if [[ -f "$SPR_DIR/.activation_log" ]]; then
        echo ""
        echo "Recent SPR Activations:"
        tail -5 "$SPR_DIR/.activation_log"
    fi
}

analyze_git_state() {
    echo ""
    echo "=== Git State Analysis ==="
    
    # Check for uncommitted changes
    if git status --porcelain | grep -q .; then
        echo "Uncommitted changes detected:"
        git status --porcelain | head -10
        echo ""
        echo "Priority: Consider organizing and committing changes"
    else
        echo "Working directory clean"
    fi
    
    # Check branch status
    current_branch=$(git branch --show-current)
    echo "Current branch: $current_branch"
}

analyze_work_patterns() {
    echo ""
    echo "=== Work Pattern Analysis ==="
    
    # Check active work items
    if [[ -d "$WORK_DIR" ]]; then
        active_work=$(find "$WORK_DIR" -name "*.active" -type f 2>/dev/null | wc -l)
        pending_work=$(find "$WORK_DIR" -name "*.todo" -type f 2>/dev/null | wc -l)
        
        echo "Active work items: $active_work"
        echo "Pending work items: $pending_work"
        
        # Show recent work
        if [[ $pending_work -gt 0 ]]; then
            echo ""
            echo "Recent work items:"
            find "$WORK_DIR" -name "*.todo" -type f -exec basename {} .todo \; 2>/dev/null | head -5
        fi
    fi
}

analyze_system_health() {
    echo ""
    echo "=== System Health Analysis ==="
    
    # Check for errors in recent logs
    error_count=0
    if [[ -d "$LOGS_DIR" ]]; then
        error_count=$(find "$LOGS_DIR" -name "*.log" -mtime -1 -exec grep -l "ERROR\|FAIL" {} \; 2>/dev/null | wc -l)
    fi
    
    if [[ $error_count -gt 0 ]]; then
        echo "⚠️  Errors found in $error_count log files"
        echo "Priority: Investigate and fix errors"
    else
        echo "✓ No recent errors detected"
    fi
    
    # Check script integrity
    missing_scripts=0
    for script in "suggest_work_items.sh" "validate_patterns.sh" "benchmark_spr.sh"; do
        if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
            echo "⚠️  Missing script: $script"
            ((missing_scripts++))
        fi
    done
    
    if [[ $missing_scripts -gt 0 ]]; then
        echo "Priority: Implement $missing_scripts missing scripts"
    fi
}

generate_priorities() {
    echo ""
    echo "=== Priority Recommendations ==="
    echo ""
    
    # Priority scoring
    declare -A priorities
    
    # Check for critical issues
    if [[ -d "$LOGS_DIR" ]] && find "$LOGS_DIR" -name "*.log" -mtime -1 -exec grep -q "ERROR\|FAIL" {} \; 2>/dev/null; then
        priorities["Fix system errors"]=100
    fi
    
    # Check for missing components
    if [[ ! -f "$SCRIPT_DIR/suggest_work_items.sh" ]]; then
        priorities["Implement missing scripts"]=90
    fi
    
    # Check for uncommitted work
    if git status --porcelain | grep -q .; then
        priorities["Organize and commit changes"]=80
    fi
    
    # Check for pending work
    if [[ -d "$WORK_DIR" ]] && find "$WORK_DIR" -name "*.todo" -type f 2>/dev/null | grep -q .; then
        priorities["Complete pending work items"]=70
    fi
    
    # Check SPR suggestions
    if [[ -f "$SPR_DIR/predicted_needs.spr" ]]; then
        if grep -q "validation\|testing" "$SPR_DIR/predicted_needs.spr"; then
            priorities["Run validation and tests"]=60
        fi
    fi
    
    # Sort and display priorities
    echo "Recommended Focus Areas (by priority):"
    echo ""
    
    # Sort priorities by value
    for task in "${!priorities[@]}"; do
        echo "${priorities[$task]} $task"
    done | sort -rn | while read score task; do
        echo "[$score] $task"
    done
}

# Main execution
main() {
    echo "CDCS Priority Analysis - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================================"
    
    analyze_spr_signals
    analyze_git_state
    analyze_work_patterns
    analyze_system_health
    generate_priorities
    
    echo ""
    echo "Analysis complete."
}

# Execute
main "$@"
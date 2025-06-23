#!/bin/bash

##############################################################################
# Claude's Personal CDCS Dashboard
# Shows everything happening in the system - no UI, just shell output
##############################################################################

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"
WORK_DIR="/Users/sac/claude-desktop-context/work"
PATTERNS_DIR="/Users/sac/claude-desktop-context/patterns"
MEMORY_DIR="/Users/sac/claude-desktop-context/memory"
REFRESH_INTERVAL="${1:-5}" # Default 5 seconds

# Clear screen and set up terminal
clear
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           🧠 Claude's CDCS System Dashboard 🧠                 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to format numbers
format_number() {
    printf "%'d" "$1" 2>/dev/null || echo "$1"
}

# Function to get file age
get_file_age() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local mod_time=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null)
        local now=$(date +%s)
        local age=$((now - mod_time))
        
        if [[ $age -lt 60 ]]; then
            echo "${age}s ago"
        elif [[ $age -lt 3600 ]]; then
            echo "$((age / 60))m ago"
        elif [[ $age -lt 86400 ]]; then
            echo "$((age / 3600))h ago"
        else
            echo "$((age / 86400))d ago"
        fi
    else
        echo "N/A"
    fi
}

# Main dashboard loop
while true; do
    # Move cursor to top
    tput cup 7 0
    
    # System Overview
    echo -e "${WHITE}═══ SYSTEM OVERVIEW ═══${NC}"
    echo -e "Current Time: ${GREEN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "Uptime: ${GREEN}$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')${NC}"
    echo ""
    
    # OpenTelemetry Status
    echo -e "${WHITE}═══ OPENTELEMETRY STATUS ═══${NC}"
    
    # Check collector status
    if curl -s http://localhost:4318/health >/dev/null 2>&1; then
        echo -e "Collector: ${GREEN}● RUNNING${NC} (http://localhost:4318)"
    else
        echo -e "Collector: ${RED}● DOWN${NC}"
    fi
    
    # Trace statistics
    total_traces=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -exec cat {} \; 2>/dev/null | wc -l)
    recent_traces=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -1 -exec cat {} \; 2>/dev/null | wc -l)
    unique_operations=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -exec cat {} \; 2>/dev/null | \
        jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name' 2>/dev/null | sort -u | wc -l)
    
    echo -e "Total Spans: ${BLUE}$(format_number $total_traces)${NC}"
    echo -e "Recent Spans (1m): ${YELLOW}$(format_number $recent_traces)${NC}"
    echo -e "Unique Operations: ${PURPLE}$(format_number $unique_operations)${NC}"
    echo ""
    
    # Recent Activity
    echo -e "${WHITE}═══ RECENT ACTIVITY ═══${NC}"
    echo -e "${CYAN}Last 5 Operations:${NC}"
    find "$TELEMETRY_DIR/data" -name "*.jsonl" -exec cat {} \; 2>/dev/null | \
        tail -5 | \
        jq -r '.resourceSpans[0].scopeSpans[0].spans[0].name // "unknown"' 2>/dev/null | \
        sed 's/^/  → /'
    echo ""
    
    # Work Claims Status
    echo -e "${WHITE}═══ WORK CLAIMS ═══${NC}"
    if [[ -f "$WORK_DIR/work_claims.json" ]]; then
        active_claims=$(jq -r 'map(select(.status != "completed")) | length' "$WORK_DIR/work_claims.json" 2>/dev/null || echo "0")
        completed_claims=$(jq -r 'map(select(.status == "completed")) | length' "$WORK_DIR/work_claims.json" 2>/dev/null || echo "0")
        
        echo -e "Active Claims: ${YELLOW}$active_claims${NC}"
        echo -e "Completed: ${GREEN}$completed_claims${NC}"
        
        # Show active work
        if [[ $active_claims -gt 0 ]]; then
            echo -e "${CYAN}Active Work:${NC}"
            jq -r '.[] | select(.status != "completed") | "  → \(.type): \(.description) [\(.progress // 0)%]"' \
                "$WORK_DIR/work_claims.json" 2>/dev/null | head -3
        fi
    else
        echo -e "${RED}No work claims file found${NC}"
    fi
    echo ""
    
    # Pattern Cache Status
    echo -e "${WHITE}═══ PATTERN RECOGNITION ═══${NC}"
    if [[ -d "$PATTERNS_DIR/cache" ]]; then
        pattern_count=$(find "$PATTERNS_DIR/cache" -name "*.json" 2>/dev/null | wc -l)
        last_refresh=$(get_file_age "$PATTERNS_DIR/cache/last_refresh.txt")
        
        echo -e "Cached Patterns: ${BLUE}$pattern_count${NC}"
        echo -e "Last Refresh: ${YELLOW}$last_refresh${NC}"
    else
        echo -e "${RED}Pattern cache not initialized${NC}"
    fi
    echo ""
    
    # Memory System Status
    echo -e "${WHITE}═══ MEMORY SYSTEM ═══${NC}"
    if [[ -d "$MEMORY_DIR/sessions" ]]; then
        session_count=$(find "$MEMORY_DIR/sessions" -name "*.md" 2>/dev/null | wc -l)
        current_session=$(readlink "$MEMORY_DIR/sessions/current.link" 2>/dev/null | xargs basename 2>/dev/null)
        
        echo -e "Total Sessions: ${BLUE}$session_count${NC}"
        echo -e "Current Session: ${GREEN}${current_session:-none}${NC}"
        
        # Show recent sessions
        echo -e "${CYAN}Recent Sessions:${NC}"
        find "$MEMORY_DIR/sessions" -name "*.md" -exec basename {} \; 2>/dev/null | \
            sort -r | head -3 | sed 's/^/  → /'
    else
        echo -e "${RED}Memory system not initialized${NC}"
    fi
    echo ""
    
    # System Resources
    echo -e "${WHITE}═══ SYSTEM RESOURCES ═══${NC}"
    
    # Disk usage for CDCS
    cdcs_size=$(du -sh /Users/sac/claude-desktop-context 2>/dev/null | awk '{print $1}')
    echo -e "CDCS Size: ${BLUE}$cdcs_size${NC}"
    
    # File counts
    total_files=$(find /Users/sac/claude-desktop-context -type f 2>/dev/null | wc -l)
    echo -e "Total Files: ${PURPLE}$(format_number $total_files)${NC}"
    
    # Memory usage (if we can get it)
    if command -v vm_stat >/dev/null 2>&1; then
        free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        active_pages=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
        page_size=4096
        free_mb=$((free_pages * page_size / 1024 / 1024))
        active_mb=$((active_pages * page_size / 1024 / 1024))
        echo -e "Memory Free: ${GREEN}${free_mb}MB${NC} | Active: ${YELLOW}${active_mb}MB${NC}"
    fi
    echo ""
    
    # Error Detection
    echo -e "${WHITE}═══ ERROR MONITORING ═══${NC}"
    
    # Check for recent errors in logs
    error_count=$(find "$TELEMETRY_DIR/logs" -name "*.jsonl" -mmin -5 -exec grep -i "error" {} \; 2>/dev/null | wc -l)
    if [[ $error_count -gt 0 ]]; then
        echo -e "${RED}⚠️  Recent Errors: $error_count${NC}"
        # Show last error
        last_error=$(find "$TELEMETRY_DIR/logs" -name "*.jsonl" -exec grep -i "error" {} \; 2>/dev/null | \
            tail -1 | jq -r '.message' 2>/dev/null)
        [[ -n "$last_error" ]] && echo -e "  Last: ${RED}$last_error${NC}"
    else
        echo -e "${GREEN}✓ No recent errors${NC}"
    fi
    echo ""
    
    # Active Processes
    echo -e "${WHITE}═══ CDCS PROCESSES ═══${NC}"
    cdcs_procs=$(ps aux | grep -E "(coordination_helper|otel|telemetry)" | grep -v grep | wc -l)
    echo -e "Active CDCS Processes: ${BLUE}$cdcs_procs${NC}"
    
    # Show any running coordination helpers
    if ps aux | grep -q "[c]oordination_helper"; then
        echo -e "${YELLOW}● Coordination helper running${NC}"
    fi
    
    # Show collector if running
    if ps aux | grep -q "[o]telcol"; then
        echo -e "${GREEN}● OpenTelemetry collector active${NC}"
    fi
    echo ""
    
    # Quick Stats Bar
    echo -e "${WHITE}═══ QUICK STATS ═══${NC}"
    echo -n "Traces/min: "
    
    # Calculate traces per minute
    traces_1m=$(find "$TELEMETRY_DIR/data" -name "*.jsonl" -mmin -1 -exec cat {} \; 2>/dev/null | wc -l)
    if [[ $traces_1m -gt 50 ]]; then
        echo -e "${RED}$traces_1m${NC} (high)"
    elif [[ $traces_1m -gt 10 ]]; then
        echo -e "${YELLOW}$traces_1m${NC} (moderate)"
    else
        echo -e "${GREEN}$traces_1m${NC} (low)"
    fi
    
    # Health indicator
    echo -n "System Health: "
    if [[ $error_count -eq 0 ]] && [[ $traces_1m -lt 100 ]]; then
        echo -e "${GREEN}● HEALTHY${NC}"
    elif [[ $error_count -lt 5 ]]; then
        echo -e "${YELLOW}● WARNING${NC}"
    else
        echo -e "${RED}● CRITICAL${NC}"
    fi
    
    # Footer
    echo ""
    echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
    echo -e "Refresh: ${WHITE}${REFRESH_INTERVAL}s${NC} | Press ${WHITE}Ctrl+C${NC} to exit"
    
    # Sleep before refresh
    sleep "$REFRESH_INTERVAL"
done
#!/bin/bash

##############################################################################
# CDCS OpenTelemetry Metrics Dashboard
##############################################################################
#
# DESCRIPTION:
#   Real-time metrics dashboard for Claude Desktop Context System
#   Shows comprehensive observability data from all instrumented components
#
# USAGE:
#   ./metrics_dashboard.sh [refresh_interval]
#   ./metrics_dashboard.sh 5  # Refresh every 5 seconds
#
##############################################################################

set -euo pipefail

# Load OpenTelemetry library
source /Users/sac/claude-desktop-context/telemetry/otel_lib.sh

# Initialize OpenTelemetry for dashboard
otel_init "metrics_dashboard" "cdcs-observability"

# Configuration
TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"
COORDINATION_DIR="/Users/sac/claude-desktop-context/coordination"
REFRESH_INTERVAL="${1:-10}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Display functions
header() { echo -e "${PURPLE}$1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
metric() { echo -e "${CYAN}📊 $1${NC}"; }

# Start dashboard trace
TRACE_ID=$(otel_start_trace "metrics.dashboard.session" "metrics_dashboard")

# Calculate metrics from telemetry data
calculate_metrics() {
    local span_file="$TELEMETRY_DIR/data/spans.jsonl"
    local log_file="$TELEMETRY_DIR/logs/structured.jsonl"
    local metrics_file="$TELEMETRY_DIR/metrics/custom_metrics.jsonl"
    
    # Trace metrics
    local total_traces=0
    local successful_traces=0
    local failed_traces=0
    local avg_duration=0
    
    if [[ -f "$span_file" ]]; then
        total_traces=$(wc -l < "$span_file" 2>/dev/null || echo 0)
        
        if command -v jq >/dev/null 2>&1 && [[ $total_traces -gt 0 ]]; then
            successful_traces=$(jq -r 'select(.resourceSpans[0].scopeSpans[0].spans[0].status.code == "STATUS_CODE_OK") | 1' "$span_file" 2>/dev/null | wc -l || echo 0)
            failed_traces=$((total_traces - successful_traces))
            
            # Calculate average duration from recent spans
            avg_duration=$(jq -r '.resourceSpans[0].scopeSpans[0].spans[0].attributes[] | select(.key == "duration_ms") | .value.intValue' "$span_file" 2>/dev/null | tail -20 | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')
        fi
    fi
    
    # Log metrics
    local total_logs=0
    local error_logs=0
    local warn_logs=0
    
    if [[ -f "$log_file" ]]; then
        total_logs=$(wc -l < "$log_file" 2>/dev/null || echo 0)
        
        if command -v jq >/dev/null 2>&1 && [[ $total_logs -gt 0 ]]; then
            error_logs=$(jq -r 'select(.level == "ERROR") | 1' "$log_file" 2>/dev/null | wc -l || echo 0)
            warn_logs=$(jq -r 'select(.level == "WARN") | 1' "$log_file" 2>/dev/null | wc -l || echo 0)
        fi
    fi
    
    # Custom metrics
    local coordination_claims=0
    local automation_executions=0
    local ollama_inferences=0
    
    if [[ -f "$metrics_file" ]]; then
        if command -v jq >/dev/null 2>&1; then
            coordination_claims=$(jq -r 'select(.metric_name == "work.claims_successful") | .metric_value' "$metrics_file" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
            automation_executions=$(jq -r 'select(.metric_name == "automation.executions_started") | .metric_value' "$metrics_file" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
            ollama_inferences=$(jq -r 'select(.metric_name == "ollama.inference_success") | .metric_value' "$metrics_file" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        fi
    fi
    
    # System metrics
    local disk_usage=$(df /Users/sac/claude-desktop-context | tail -1 | awk '{print $5}' | sed 's/%//')
    local load_avg=$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    # Export metrics
    export METRIC_TOTAL_TRACES=$total_traces
    export METRIC_SUCCESSFUL_TRACES=$successful_traces
    export METRIC_FAILED_TRACES=$failed_traces
    export METRIC_AVG_DURATION=$avg_duration
    export METRIC_TOTAL_LOGS=$total_logs
    export METRIC_ERROR_LOGS=$error_logs
    export METRIC_WARN_LOGS=$warn_logs
    export METRIC_COORDINATION_CLAIMS=$coordination_claims
    export METRIC_AUTOMATION_EXECUTIONS=$automation_executions
    export METRIC_OLLAMA_INFERENCES=$ollama_inferences
    export METRIC_DISK_USAGE=$disk_usage
    export METRIC_LOAD_AVG=$load_avg
}

# Display system health status
show_system_health() {
    local health_score=100
    local health_status="HEALTHY"
    local health_color=$GREEN
    
    # Check various health indicators
    if [[ $METRIC_DISK_USAGE -gt 90 ]]; then
        health_score=$((health_score - 20))
        health_status="DEGRADED"
        health_color=$YELLOW
    fi
    
    if [[ $METRIC_FAILED_TRACES -gt $((METRIC_SUCCESSFUL_TRACES / 2)) ]] && [[ $METRIC_TOTAL_TRACES -gt 10 ]]; then
        health_score=$((health_score - 30))
        health_status="CRITICAL"
        health_color=$RED
    fi
    
    if [[ $METRIC_ERROR_LOGS -gt 10 ]]; then
        health_score=$((health_score - 15))
        if [[ "$health_status" != "CRITICAL" ]]; then
            health_status="DEGRADED"
            health_color=$YELLOW
        fi
    fi
    
    echo -e "${health_color}🏥 System Health: $health_status ($health_score/100)${NC}"
}

# Main dashboard display
show_dashboard() {
    clear
    
    header "🔭 CDCS OPENTELEMETRY METRICS DASHBOARD"
    header "========================================="
    echo ""
    
    # Calculate current metrics
    calculate_metrics
    
    # System Health
    show_system_health
    echo ""
    
    # OpenTelemetry Status
    header "📡 OPENTELEMETRY STATUS"
    if curl -s -f http://localhost:8888/metrics >/dev/null 2>&1; then
        success "Collector: Running (http://localhost:8888)"
    else
        error "Collector: Not responding"
    fi
    
    if curl -s -f http://localhost:8889/metrics >/dev/null 2>&1; then
        success "Prometheus: Running (http://localhost:8889)"
    else
        warn "Prometheus: Not available"
    fi
    
    if command -v docker >/dev/null 2>&1 && docker ps | grep -q jaeger; then
        success "Jaeger UI: Running (http://localhost:16686)"
    else
        warn "Jaeger UI: Not running"
    fi
    echo ""
    
    # Trace Metrics
    header "🔍 DISTRIBUTED TRACING"
    metric "Total Traces: $METRIC_TOTAL_TRACES"
    metric "Successful: $METRIC_SUCCESSFUL_TRACES"
    metric "Failed: $METRIC_FAILED_TRACES"
    if [[ $METRIC_TOTAL_TRACES -gt 0 ]]; then
        local success_rate=$(echo "scale=1; $METRIC_SUCCESSFUL_TRACES * 100.0 / $METRIC_TOTAL_TRACES" | bc -l)
        metric "Success Rate: ${success_rate}%"
    fi
    metric "Avg Duration: ${METRIC_AVG_DURATION}ms"
    echo ""
    
    # Log Metrics
    header "📝 LOGGING METRICS"
    metric "Total Log Entries: $METRIC_TOTAL_LOGS"
    metric "Error Logs: $METRIC_ERROR_LOGS"
    metric "Warning Logs: $METRIC_WARN_LOGS"
    if [[ $METRIC_TOTAL_LOGS -gt 0 ]]; then
        local error_rate=$(echo "scale=1; $METRIC_ERROR_LOGS * 100.0 / $METRIC_TOTAL_LOGS" | bc -l)
        metric "Error Rate: ${error_rate}%"
    fi
    echo ""
    
    # CDCS Specific Metrics
    header "🤖 CDCS COORDINATION METRICS"
    metric "Work Claims: $METRIC_COORDINATION_CLAIMS"
    metric "Automation Executions: $METRIC_AUTOMATION_EXECUTIONS"
    metric "Ollama Inferences: $METRIC_OLLAMA_INFERENCES"
    
    # Show active work items
    if [[ -f "$COORDINATION_DIR/work_claims.json" ]] && command -v jq >/dev/null 2>&1; then
        local active_work=$(jq '[.[] | select(.status == "active")] | length' "$COORDINATION_DIR/work_claims.json" 2>/dev/null || echo 0)
        metric "Active Work Items: $active_work"
    fi
    echo ""
    
    # System Metrics
    header "💻 SYSTEM METRICS"
    metric "Disk Usage: ${METRIC_DISK_USAGE}%"
    metric "Load Average: $METRIC_LOAD_AVG"
    
    # Memory usage
    if command -v vm_stat >/dev/null 2>&1; then
        local free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        local page_size=4096
        local free_mb=$((free_pages * page_size / 1024 / 1024))
        metric "Free Memory: ${free_mb}MB"
    fi
    echo ""
    
    # Recent Activity
    header "📊 RECENT ACTIVITY (Last 10 Events)"
    if [[ -f "$TELEMETRY_DIR/logs/events.jsonl" ]]; then
        tail -10 "$TELEMETRY_DIR/logs/events.jsonl" 2>/dev/null | while IFS= read -r line; do
            if command -v jq >/dev/null 2>&1; then
                local timestamp=$(echo "$line" | jq -r '.timestamp' 2>/dev/null || echo "unknown")
                local event_name=$(echo "$line" | jq -r '.event_name' 2>/dev/null || echo "unknown")
                local description=$(echo "$line" | jq -r '.description' 2>/dev/null || echo "")
                info "[$timestamp] $event_name: $description"
            fi
        done
    else
        info "No recent events"
    fi
    echo ""
    
    # Footer
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    header "Last Updated: $timestamp | Refresh: ${REFRESH_INTERVAL}s | Trace: $TRACE_ID"
    echo ""
    echo "Commands: Ctrl+C to exit | Open Jaeger: open http://localhost:16686"
}

# Record dashboard metrics
record_dashboard_metrics() {
    otel_record_metric "dashboard.views" 1 "counter"
    otel_record_metric "dashboard.traces_displayed" "$METRIC_TOTAL_TRACES" "gauge"
    otel_record_metric "dashboard.system_health_score" "$((health_score))" "gauge"
}

# Signal handlers
cleanup() {
    otel_log "INFO" "Dashboard session ending"
    otel_end_trace "ok"
    echo ""
    echo "Dashboard stopped."
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main dashboard loop
main() {
    otel_log "INFO" "Starting metrics dashboard" "{\"refresh_interval\": $REFRESH_INTERVAL}"
    
    while true; do
        otel_start_span "dashboard.refresh" "metrics_dashboard"
        
        show_dashboard
        record_dashboard_metrics
        
        otel_end_span "ok"
        
        sleep "$REFRESH_INTERVAL"
    done
}

# Check dependencies
if ! command -v bc >/dev/null 2>&1; then
    error "bc calculator not found - install with: brew install bc"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found - some metrics may be limited"
fi

# Start dashboard
main
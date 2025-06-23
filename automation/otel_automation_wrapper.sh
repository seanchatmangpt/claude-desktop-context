#!/bin/bash

##############################################################################
# OpenTelemetry Automation Wrapper for CDCS
##############################################################################
#
# DESCRIPTION:
#   Wraps any CDCS automation script with comprehensive OpenTelemetry
#   instrumentation for observability across all automated processes
#
# USAGE:
#   ./otel_automation_wrapper.sh <script_name> <operation_name> [args...]
#   ./otel_automation_wrapper.sh pattern_miner.py "pattern.mining.hourly"
#   ./otel_automation_wrapper.sh memory_optimizer.py "memory.optimization.daily"
#
##############################################################################

set -euo pipefail

# Load OpenTelemetry library
source /Users/sac/claude-desktop-context/telemetry/otel_lib.sh

# Initialize OpenTelemetry for automation
otel_init "cdcs_automation" "cdcs-automation"

# Configuration
AUTOMATION_DIR="/Users/sac/claude-desktop-context/automation"
LOG_DIR="$AUTOMATION_DIR/logs"
PYTHON_PATH="/usr/bin/python3"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Parse arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <script_name> <operation_name> [args...]"
    echo "Examples:"
    echo "  $0 pattern_miner.py pattern.mining.hourly"
    echo "  $0 memory_optimizer.py memory.optimization.daily --force"
    exit 1
fi

SCRIPT_NAME="$1"
OPERATION_NAME="$2"
shift 2
SCRIPT_ARGS="$@"

# Validate script exists
SCRIPT_PATH="$AUTOMATION_DIR/$SCRIPT_NAME"
if [[ ! -f "$SCRIPT_PATH" ]]; then
    otel_log "ERROR" "Script not found: $SCRIPT_PATH"
    otel_handle_error "Script not found" 1
fi

# Start comprehensive tracing
TRACE_ID=$(otel_start_trace "$OPERATION_NAME" "cdcs_automation")
otel_log "INFO" "Starting automated operation" "{\"script\": \"$SCRIPT_NAME\", \"operation\": \"$OPERATION_NAME\", \"args\": \"$SCRIPT_ARGS\"}"

# Set up automation context
otel_set_attributes "{
    \"automation.script_name\": \"$SCRIPT_NAME\",
    \"automation.operation_name\": \"$OPERATION_NAME\",
    \"automation.trigger\": \"cron\",
    \"automation.environment\": \"production\",
    \"automation.trace_id\": \"$TRACE_ID\"
}"

# Record automation start metrics
otel_record_metric "automation.executions_started" 1 "counter" "{\"script\": \"$SCRIPT_NAME\", \"operation\": \"$OPERATION_NAME\"}"

# Pre-execution health checks
otel_start_span "automation.health_check" "health_monitor"

# Check disk space
DISK_USAGE=$(df /Users/sac/claude-desktop-context | tail -1 | awk '{print $5}' | sed 's/%//')
otel_record_metric "system.disk_usage_percent" "$DISK_USAGE" "gauge"

if [[ $DISK_USAGE -gt 90 ]]; then
    otel_log "WARN" "High disk usage detected: ${DISK_USAGE}%"
    otel_add_event "disk.high_usage" "Disk usage above 90%"
fi

# Check memory usage
if command -v vm_stat >/dev/null 2>&1; then
    MEMORY_PRESSURE=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    otel_record_metric "system.memory_free_pages" "$MEMORY_PRESSURE" "gauge"
fi

# Check if OpenTelemetry collector is running
if ! otel_health_check; then
    otel_log "WARN" "OpenTelemetry collector not responding - telemetry may be incomplete"
fi

otel_end_span "ok"

# Execute the automation script with comprehensive monitoring
otel_start_span "automation.script_execution" "script_executor"

# Determine execution method based on file extension
case "${SCRIPT_NAME##*.}" in
    "py"|"python")
        EXECUTOR="$PYTHON_PATH"
        ;;
    "sh"|"bash")
        EXECUTOR="/bin/bash"
        ;;
    *)
        if [[ -x "$SCRIPT_PATH" ]]; then
            EXECUTOR=""
        else
            otel_log "ERROR" "Unknown script type or not executable: $SCRIPT_NAME"
            otel_end_span "error" "Unknown script type"
            otel_handle_error "Unknown script type" 1
        fi
        ;;
esac

# Create unique log file for this execution
EXECUTION_ID="$(date +%Y%m%d_%H%M%S)_$$"
EXECUTION_LOG="$LOG_DIR/${SCRIPT_NAME}_${EXECUTION_ID}.log"
ERROR_LOG="$LOG_DIR/${SCRIPT_NAME}_${EXECUTION_ID}.err"

otel_log "INFO" "Starting script execution" "{\"executor\": \"$EXECUTOR\", \"log_file\": \"$EXECUTION_LOG\"}"

# Execute with timing and capture all output
START_TIME=$(date +%s%N)

if [[ -n "$EXECUTOR" ]]; then
    COMMAND="$EXECUTOR $SCRIPT_PATH $SCRIPT_ARGS"
else
    COMMAND="$SCRIPT_PATH $SCRIPT_ARGS"
fi

# Execute with comprehensive error handling
EXIT_CODE=0
if timeout 3600 bash -c "$COMMAND" > "$EXECUTION_LOG" 2> "$ERROR_LOG"; then
    otel_log "INFO" "Script execution completed successfully"
    otel_add_event "execution.completed" "Script finished successfully"
else
    EXIT_CODE=$?
    otel_log "ERROR" "Script execution failed" "{\"exit_code\": $EXIT_CODE}"
    otel_add_event "execution.failed" "Script execution failed"
fi

END_TIME=$(date +%s%N)
DURATION_NS=$((END_TIME - START_TIME))
DURATION_MS=$((DURATION_NS / 1000000))
DURATION_SECONDS=$((DURATION_NS / 1000000000))

# Record execution metrics
otel_record_metric "automation.execution_duration_ms" "$DURATION_MS" "histogram" "{\"script\": \"$SCRIPT_NAME\"}"
otel_record_metric "automation.execution_duration_seconds" "$DURATION_SECONDS" "histogram" "{\"script\": \"$SCRIPT_NAME\"}"

# Analyze output for insights
if [[ -s "$EXECUTION_LOG" ]]; then
    OUTPUT_SIZE=$(wc -l < "$EXECUTION_LOG")
    otel_record_metric "automation.output_lines" "$OUTPUT_SIZE" "gauge" "{\"script\": \"$SCRIPT_NAME\"}"
    
    # Look for common success/failure patterns
    if grep -q -i "success\|completed\|done\|finished" "$EXECUTION_LOG"; then
        otel_add_event "pattern.success_detected" "Success indicators found in output"
    fi
    
    if grep -q -i "error\|failed\|exception\|traceback" "$EXECUTION_LOG"; then
        otel_add_event "pattern.error_detected" "Error indicators found in output"
        otel_log "WARN" "Error patterns detected in script output"
    fi
fi

if [[ -s "$ERROR_LOG" ]]; then
    ERROR_SIZE=$(wc -l < "$ERROR_LOG")
    otel_record_metric "automation.error_lines" "$ERROR_SIZE" "gauge" "{\"script\": \"$SCRIPT_NAME\"}"
    
    if [[ $ERROR_SIZE -gt 0 ]]; then
        otel_log "WARN" "Script produced error output" "{\"error_lines\": $ERROR_SIZE}"
        # Include first few error lines in telemetry
        ERROR_SAMPLE=$(head -3 "$ERROR_LOG" | tr '\n' ' ')
        otel_add_event "execution.error_output" "Error output detected" "{\"sample\": \"$ERROR_SAMPLE\"}"
    fi
fi

# End script execution span
if [[ $EXIT_CODE -eq 0 ]]; then
    otel_end_span "ok"
    otel_record_metric "automation.executions_successful" 1 "counter" "{\"script\": \"$SCRIPT_NAME\"}"
else
    otel_end_span "error" "Script failed with exit code $EXIT_CODE"
    otel_record_metric "automation.executions_failed" 1 "counter" "{\"script\": \"$SCRIPT_NAME\"}"
fi

# Post-execution analysis
otel_start_span "automation.post_analysis" "post_processor"

# Archive logs if successful, keep recent logs if failed
if [[ $EXIT_CODE -eq 0 ]]; then
    # Move logs to archive directory
    ARCHIVE_DIR="$LOG_DIR/archive/$(date +%Y%m)"
    mkdir -p "$ARCHIVE_DIR"
    
    if [[ -s "$EXECUTION_LOG" ]]; then
        mv "$EXECUTION_LOG" "$ARCHIVE_DIR/"
        otel_add_event "log.archived" "Execution log archived successfully"
    fi
    
    if [[ -s "$ERROR_LOG" ]]; then
        mv "$ERROR_LOG" "$ARCHIVE_DIR/"
    else
        rm -f "$ERROR_LOG"
    fi
else
    # Keep failed execution logs for debugging
    otel_log "INFO" "Keeping failed execution logs for debugging" "{\"execution_log\": \"$EXECUTION_LOG\", \"error_log\": \"$ERROR_LOG\"}"
fi

# Cleanup old archived logs (keep last 30 days)
find "$LOG_DIR/archive" -type f -mtime +30 -delete 2>/dev/null || true

otel_end_span "ok"

# Final metrics and summary
otel_log "INFO" "Automation execution summary" "{
    \"script\": \"$SCRIPT_NAME\",
    \"operation\": \"$OPERATION_NAME\",
    \"duration_seconds\": $DURATION_SECONDS,
    \"exit_code\": $EXIT_CODE,
    \"trace_id\": \"$TRACE_ID\"
}"

# End trace with appropriate status
if [[ $EXIT_CODE -eq 0 ]]; then
    otel_end_trace "ok"
else
    otel_end_trace "error" "Automation script failed"
fi

# Exit with the same code as the wrapped script
exit $EXIT_CODE
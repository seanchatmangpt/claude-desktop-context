#!/bin/bash

##############################################################################
# OpenTelemetry Library for CDCS
##############################################################################
#
# DESCRIPTION:
#   Unified OpenTelemetry instrumentation library for all CDCS components
#   Provides consistent tracing, metrics, and logging across the entire system
#
# USAGE:
#   source /Users/sac/claude-desktop-context/telemetry/otel_lib.sh
#   otel_start_trace "operation_name" "component_name"
#   otel_add_event "event_name" "description"
#   otel_end_trace "success"
#
# FEATURES:
#   - Distributed tracing with context propagation
#   - Custom metrics collection
#   - Structured logging
#   - Automatic span lifecycle management
#   - Performance monitoring
#   - Error tracking and alerting
#
##############################################################################

# OpenTelemetry configuration
OTEL_CONFIG_DIR="${OTEL_CONFIG_DIR:-/Users/sac/claude-desktop-context/telemetry}"
OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-cdcs-system}"
OTEL_SERVICE_VERSION="${OTEL_SERVICE_VERSION:-2.0.0}"
OTEL_ENVIRONMENT="${OTEL_ENVIRONMENT:-development}"
OTEL_COLLECTOR_ENDPOINT="${OTEL_COLLECTOR_ENDPOINT:-http://localhost:4318}"

# Global trace context
OTEL_CURRENT_TRACE_ID=""
OTEL_CURRENT_SPAN_ID=""
OTEL_PARENT_SPAN_ID=""
OTEL_TRACE_STACK=()
OTEL_SPAN_START_TIME=""
OTEL_COMPONENT_NAME=""

# Create telemetry directories
mkdir -p "$OTEL_CONFIG_DIR"/{logs,data,metrics}

# Generate cryptographically secure IDs
otel_generate_trace_id() {
    echo "$(openssl rand -hex 16)"
}

otel_generate_span_id() {
    echo "$(openssl rand -hex 8)"
}

# Get high-precision timestamp
otel_timestamp() {
    python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%fZ'))" 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%S.000Z
}

otel_timestamp_nanos() {
    python3 -c "import time; print(int(time.time() * 1000000000))"
}

# Initialize OpenTelemetry context for a script/component
otel_init() {
    local component_name="$1"
    local service_name="${2:-$OTEL_SERVICE_NAME}"
    
    OTEL_COMPONENT_NAME="$component_name"
    export OTEL_SERVICE_NAME="$service_name"
    export OTEL_SERVICE_VERSION="$OTEL_SERVICE_VERSION"
    export OTEL_ENVIRONMENT="$OTEL_ENVIRONMENT"
    
    # Create component-specific log file
    local log_file="$OTEL_CONFIG_DIR/logs/${component_name}_$(date +%Y%m%d).log"
    # Only redirect if file descriptor is not already in use
    if ! { true >&3; } 2>/dev/null; then
        exec 3>>"$log_file" 2>/dev/null || true
    fi
    
    otel_log "INFO" "OpenTelemetry initialized for component: $component_name"
}

# Start a new trace
otel_start_trace() {
    local operation_name="$1"
    local component_name="${2:-$OTEL_COMPONENT_NAME}"
    local parent_trace_id="$3"
    local parent_span_id="$4"
    
    # Generate new trace ID if not provided
    if [[ -z "$parent_trace_id" ]]; then
        OTEL_CURRENT_TRACE_ID="$(otel_generate_trace_id)"
        OTEL_PARENT_SPAN_ID=""
    else
        OTEL_CURRENT_TRACE_ID="$parent_trace_id"
        OTEL_PARENT_SPAN_ID="$parent_span_id"
    fi
    
    # Generate new span ID
    OTEL_CURRENT_SPAN_ID="$(otel_generate_span_id)"
    OTEL_SPAN_START_TIME="$(otel_timestamp_nanos)"
    
    # Push to trace stack for nested spans
    OTEL_TRACE_STACK+=("$OTEL_CURRENT_SPAN_ID:$operation_name:$OTEL_SPAN_START_TIME")
    
    # Set environment variables for child processes
    export OTEL_TRACE_ID="$OTEL_CURRENT_TRACE_ID"
    export OTEL_SPAN_ID="$OTEL_CURRENT_SPAN_ID"
    export OTEL_PARENT_SPAN_ID="$OTEL_PARENT_SPAN_ID"
    
    otel_log "TRACE" "Started trace: $operation_name (trace_id=$OTEL_CURRENT_TRACE_ID, span_id=$OTEL_CURRENT_SPAN_ID)"
    
    # Send span start event
    otel_send_span_start "$operation_name" "$component_name"
    
    echo "$OTEL_CURRENT_TRACE_ID"
}

# Start a child span
otel_start_span() {
    local operation_name="$1"
    local component_name="${2:-$OTEL_COMPONENT_NAME}"
    
    # Current span becomes parent
    local parent_span_id="$OTEL_CURRENT_SPAN_ID"
    
    # Generate new span ID
    OTEL_CURRENT_SPAN_ID="$(otel_generate_span_id)"
    OTEL_PARENT_SPAN_ID="$parent_span_id"
    OTEL_SPAN_START_TIME="$(otel_timestamp_nanos)"
    
    # Push to trace stack
    OTEL_TRACE_STACK+=("$OTEL_CURRENT_SPAN_ID:$operation_name:$OTEL_SPAN_START_TIME")
    
    export OTEL_SPAN_ID="$OTEL_CURRENT_SPAN_ID"
    export OTEL_PARENT_SPAN_ID="$OTEL_PARENT_SPAN_ID"
    
    otel_log "TRACE" "Started span: $operation_name (span_id=$OTEL_CURRENT_SPAN_ID, parent=$OTEL_PARENT_SPAN_ID)"
    
    otel_send_span_start "$operation_name" "$component_name"
    
    echo "$OTEL_CURRENT_SPAN_ID"
}

# Add an event to the current span
otel_add_event() {
    local event_name="$1"
    local description="$2"
    local attributes="$3"
    
    local event_data=$(cat <<EOF
{
  "trace_id": "$OTEL_CURRENT_TRACE_ID",
  "span_id": "$OTEL_CURRENT_SPAN_ID",
  "event_name": "$event_name",
  "description": "$description",
  "timestamp": "$(otel_timestamp)",
  "attributes": ${attributes:-"{}"}
}
EOF
    )
    
    echo "$event_data" >> "$OTEL_CONFIG_DIR/logs/events.jsonl"
    otel_log "EVENT" "$event_name: $description"
}

# Add attributes to the current span
otel_set_attributes() {
    local attributes="$1"
    
    local attr_data=$(cat <<EOF
{
  "trace_id": "$OTEL_CURRENT_TRACE_ID",
  "span_id": "$OTEL_CURRENT_SPAN_ID",
  "timestamp": "$(otel_timestamp)",
  "attributes": $attributes
}
EOF
    )
    
    echo "$attr_data" >> "$OTEL_CONFIG_DIR/logs/attributes.jsonl"
}

# End the current span
otel_end_span() {
    local status="${1:-ok}"
    local error_message="$2"
    
    if [[ ${#OTEL_TRACE_STACK[@]} -eq 0 ]]; then
        otel_log "WARN" "Attempted to end span but no active spans"
        return 1
    fi
    
    # Pop from trace stack (compatible with bash 3.2)
    local stack_len=${#OTEL_TRACE_STACK[@]}
    if [[ $stack_len -eq 0 ]]; then
        return 1
    fi
    local last_index=$((stack_len - 1))
    local span_info="${OTEL_TRACE_STACK[$last_index]}"
    unset "OTEL_TRACE_STACK[$last_index]"
    
    local span_id="${span_info%%:*}"
    local operation_name="${span_info#*:}"
    operation_name="${operation_name%:*}"
    local start_time="${span_info##*:}"
    
    local end_time="$(otel_timestamp_nanos)"
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))
    
    otel_log "TRACE" "Ended span: $operation_name (duration=${duration_ms}ms, status=$status)"
    
    # Send span end event
    otel_send_span_end "$operation_name" "$status" "$duration_ms" "$error_message"
    
    # Update current span to parent if stack not empty
    local remaining_stack_len=${#OTEL_TRACE_STACK[@]}
    if [[ $remaining_stack_len -gt 0 ]]; then
        local parent_index=$((remaining_stack_len - 1))
        local parent_info="${OTEL_TRACE_STACK[$parent_index]}"
        OTEL_CURRENT_SPAN_ID="${parent_info%%:*}"
        export OTEL_SPAN_ID="$OTEL_CURRENT_SPAN_ID"
    fi
}

# End the current trace
otel_end_trace() {
    local status="${1:-ok}"
    local error_message="${2:-}"
    
    # End all remaining spans
    while [[ ${#OTEL_TRACE_STACK[@]} -gt 0 ]]; do
        otel_end_span "$status" "$error_message"
    done
    
    otel_log "TRACE" "Ended trace: $OTEL_CURRENT_TRACE_ID (status=$status)"
    
    # Clear trace context
    OTEL_CURRENT_TRACE_ID=""
    OTEL_CURRENT_SPAN_ID=""
    OTEL_PARENT_SPAN_ID=""
    OTEL_SPAN_START_TIME=""
    
    unset OTEL_TRACE_ID OTEL_SPAN_ID OTEL_PARENT_SPAN_ID
}

# Send span start to collector
otel_send_span_start() {
    local operation_name="$1"
    local component_name="$2"
    
    local span_data=$(cat <<EOF
{
  "resourceSpans": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "$OTEL_SERVICE_NAME"}},
        {"key": "service.version", "value": {"stringValue": "$OTEL_SERVICE_VERSION"}},
        {"key": "deployment.environment", "value": {"stringValue": "$OTEL_ENVIRONMENT"}},
        {"key": "cdcs.component", "value": {"stringValue": "$component_name"}},
        {"key": "host.name", "value": {"stringValue": "$(hostname)"}}
      ]
    },
    "scopeSpans": [{
      "scope": {"name": "cdcs-telemetry", "version": "1.0.0"},
      "spans": [{
        "traceId": "$OTEL_CURRENT_TRACE_ID",
        "spanId": "$OTEL_CURRENT_SPAN_ID",
        "parentSpanId": "$OTEL_PARENT_SPAN_ID",
        "name": "$operation_name",
        "kind": "SPAN_KIND_INTERNAL",
        "startTimeUnixNano": "$OTEL_SPAN_START_TIME",
        "attributes": [
          {"key": "operation.name", "value": {"stringValue": "$operation_name"}},
          {"key": "component.name", "value": {"stringValue": "$component_name"}},
          {"key": "span.kind", "value": {"stringValue": "internal"}}
        ]
      }]
    }]
  }]
}
EOF
    )
    
    # Send to collector (async)
    if command -v curl >/dev/null 2>&1; then
        curl -s -X POST "$OTEL_COLLECTOR_ENDPOINT/v1/traces" \
             -H "Content-Type: application/json" \
             -d "$span_data" >/dev/null 2>&1 &
    fi
    
    # Also write to file for backup
    echo "$span_data" >> "$OTEL_CONFIG_DIR/data/spans.jsonl"
}

# Send span end to collector
otel_send_span_end() {
    local operation_name="$1"
    local status="$2"
    local duration_ms="$3"
    local error_message="$4"
    
    local end_time="$(otel_timestamp_nanos)"
    local status_code="STATUS_CODE_OK"
    
    if [[ "$status" != "ok" ]]; then
        status_code="STATUS_CODE_ERROR"
    fi
    
    local span_data=$(cat <<EOF
{
  "resourceSpans": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "$OTEL_SERVICE_NAME"}},
        {"key": "service.version", "value": {"stringValue": "$OTEL_SERVICE_VERSION"}},
        {"key": "deployment.environment", "value": {"stringValue": "$OTEL_ENVIRONMENT"}},
        {"key": "cdcs.component", "value": {"stringValue": "$OTEL_COMPONENT_NAME"}}
      ]
    },
    "scopeSpans": [{
      "scope": {"name": "cdcs-telemetry", "version": "1.0.0"},
      "spans": [{
        "traceId": "$OTEL_CURRENT_TRACE_ID",
        "spanId": "$OTEL_CURRENT_SPAN_ID",
        "parentSpanId": "$OTEL_PARENT_SPAN_ID",
        "name": "$operation_name",
        "kind": "SPAN_KIND_INTERNAL",
        "startTimeUnixNano": "$OTEL_SPAN_START_TIME",
        "endTimeUnixNano": "$end_time",
        "status": {
          "code": "$status_code",
          "message": "$error_message"
        },
        "attributes": [
          {"key": "operation.name", "value": {"stringValue": "$operation_name"}},
          {"key": "duration_ms", "value": {"intValue": "$duration_ms"}},
          {"key": "status", "value": {"stringValue": "$status"}}
        ]
      }]
    }]
  }]
}
EOF
    )
    
    # Send to collector (async)
    if command -v curl >/dev/null 2>&1; then
        curl -s -X POST "$OTEL_COLLECTOR_ENDPOINT/v1/traces" \
             -H "Content-Type: application/json" \
             -d "$span_data" >/dev/null 2>&1 &
    fi
}

# Record a custom metric
otel_record_metric() {
    local metric_name="$1"
    local metric_value="$2"
    local metric_type="${3:-gauge}"  # counter, gauge, histogram
    local attributes="$4"
    
    local metric_data=$(cat <<EOF
{
  "timestamp": "$(otel_timestamp)",
  "trace_id": "$OTEL_CURRENT_TRACE_ID",
  "span_id": "$OTEL_CURRENT_SPAN_ID",
  "metric_name": "$metric_name",
  "metric_value": $metric_value,
  "metric_type": "$metric_type",
  "attributes": ${attributes:-"{}"},
  "component": "$OTEL_COMPONENT_NAME"
}
EOF
    )
    
    echo "$metric_data" >> "$OTEL_CONFIG_DIR/metrics/custom_metrics.jsonl"
    otel_log "METRIC" "$metric_name: $metric_value ($metric_type)"
}

# Structured logging with trace correlation
otel_log() {
    local level="$1"
    local message="$2"
    local attributes="${3:-"{}"}"
    
    local timestamp="$(otel_timestamp)"
    local log_entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "level": "$level",
  "message": "$message",
  "trace_id": "$OTEL_CURRENT_TRACE_ID",
  "span_id": "$OTEL_CURRENT_SPAN_ID",
  "component": "$OTEL_COMPONENT_NAME",
  "service": "$OTEL_SERVICE_NAME",
  "attributes": ${attributes:-"{}"}
}
EOF
    )
    
    # Write to component log and structured log
    { echo "[$timestamp] [$level] $message" >&3; } 2>/dev/null || true
    echo "$log_entry" >> "$OTEL_CONFIG_DIR/logs/structured.jsonl" 2>/dev/null || true
    
    # Also echo to stderr for immediate visibility (limit frequency)
    if [[ "$level" != "TRACE" ]]; then
        echo "[$level] $message" >&2
    fi
}

# Measure execution time of a command
otel_measure() {
    local operation_name="$1"
    shift
    local command="$@"
    
    local span_id=$(otel_start_span "$operation_name")
    local start_time=$(date +%s%N)
    
    # Execute command and capture exit code
    local exit_code=0
    eval "$command" || exit_code=$?
    
    local end_time=$(date +%s%N)
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))
    
    # Record execution metrics
    otel_record_metric "command.duration_ms" "$duration_ms" "histogram" \
        "{\"command\": \"$command\", \"exit_code\": $exit_code}"
    
    if [[ $exit_code -eq 0 ]]; then
        otel_end_span "ok"
    else
        otel_end_span "error" "Command failed with exit code $exit_code"
    fi
    
    return $exit_code
}

# Error handling with automatic span termination
otel_handle_error() {
    local error_message="$1"
    local exit_code="${2:-1}"
    
    otel_log "ERROR" "$error_message" "{\"exit_code\": $exit_code}"
    otel_end_trace "error" "$error_message"
    
    exit $exit_code
}

# Trap handler for automatic cleanup
otel_cleanup_handler() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        otel_log "ERROR" "Script terminated unexpectedly" "{\"exit_code\": $exit_code}"
        otel_end_trace "error" "Script terminated unexpectedly"
    else
        otel_end_trace "ok"
    fi
}

# Set up automatic cleanup on script exit
trap otel_cleanup_handler EXIT

# Context propagation helpers
otel_get_trace_context() {
    echo "traceparent: 00-$OTEL_CURRENT_TRACE_ID-$OTEL_CURRENT_SPAN_ID-01"
}

otel_set_trace_context() {
    local traceparent="$1"
    # Parse traceparent header: 00-trace_id-span_id-flags
    if [[ "$traceparent" =~ 00-([a-f0-9]{32})-([a-f0-9]{16})-[0-9]{2} ]]; then
        OTEL_CURRENT_TRACE_ID="${BASH_REMATCH[1]}"
        OTEL_PARENT_SPAN_ID="${BASH_REMATCH[2]}"
        export OTEL_TRACE_ID="$OTEL_CURRENT_TRACE_ID"
        export OTEL_PARENT_SPAN_ID="$OTEL_PARENT_SPAN_ID"
    fi
}

# Health check function
otel_health_check() {
    local collector_url="$OTEL_COLLECTOR_ENDPOINT"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -s -f "$collector_url/health" >/dev/null 2>&1; then
            otel_log "INFO" "OpenTelemetry collector is healthy"
            return 0
        else
            otel_log "WARN" "OpenTelemetry collector is not responding"
            return 1
        fi
    else
        otel_log "WARN" "curl not available for health checks"
        return 1
    fi
}

# Export all functions for use in sourcing scripts
export -f otel_init otel_start_trace otel_start_span otel_end_span otel_end_trace
export -f otel_add_event otel_set_attributes otel_record_metric otel_log
export -f otel_measure otel_handle_error otel_get_trace_context otel_set_trace_context
export -f otel_health_check

# Initialize telemetry logging
otel_log "INFO" "OpenTelemetry library loaded successfully"
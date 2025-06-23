#!/bin/bash

# Global error handler
handle_error() {
    local error_msg="$1"
    local error_code="${2:-1}"
    
    # Log error with trace context
    if [[ -f /Users/sac/claude-desktop-context/telemetry/otel_unified.sh ]]; then
        source /Users/sac/claude-desktop-context/telemetry/otel_unified.sh
        otel_log "error" "$error_msg"
    fi
    
    # Don't exit - just log
    return 0
}

# Set trap for errors
trap 'handle_error "Command failed: $BASH_COMMAND at line $LINENO"' ERR

export -f handle_error

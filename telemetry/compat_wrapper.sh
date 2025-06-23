#!/bin/bash
# Wrapper to handle bash 3.x compatibility

# Replace declare -g with simple variable assignment
export OTEL_CURRENT_TRACE_ID=""
export OTEL_CURRENT_SPAN_ID=""
export OTEL_TRACE_STACK=""

# Function to safely append to array (bash 3.x compatible)
safe_array_append() {
    local array_name=$1
    local value=$2
    eval "$array_name=\"\$$array_name $value\""
}

#!/bin/bash

##############################################################################
# OpenTelemetry Collector Startup Script for CDCS
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/otel-collector.yaml"
LOG_FILE="$SCRIPT_DIR/logs/collector.log"
PID_FILE="$SCRIPT_DIR/collector.pid"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️ $1${NC}"; }

# Check if collector is already running
check_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Download OpenTelemetry Collector if not present
download_collector() {
    local collector_binary="$SCRIPT_DIR/otelcol"
    
    if [[ ! -f "$collector_binary" ]]; then
        log "Downloading OpenTelemetry Collector..."
        
        # Detect architecture
        local arch="amd64"
        if [[ "$(uname -m)" == "arm64" ]]; then
            arch="arm64"
        fi
        
        local os="darwin"
        local version="0.91.0"
        local url="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${version}/otelcol_${version}_${os}_${arch}.tar.gz"
        
        log "Downloading from: $url"
        
        if command -v curl >/dev/null 2>&1; then
            curl -L "$url" | tar -xz -C "$SCRIPT_DIR" otelcol
        elif command -v wget >/dev/null 2>&1; then
            wget -qO- "$url" | tar -xz -C "$SCRIPT_DIR" otelcol
        else
            error "Neither curl nor wget available for download"
            return 1
        fi
        
        chmod +x "$collector_binary"
        success "OpenTelemetry Collector downloaded successfully"
    fi
}

# Start Jaeger for trace visualization
start_jaeger() {
    if ! command -v docker >/dev/null 2>&1; then
        warn "Docker not available - Jaeger will not be started"
        return 0
    fi
    
    # Check if Jaeger is already running
    if docker ps | grep -q jaeger-all-in-one; then
        log "Jaeger already running"
        return 0
    fi
    
    log "Starting Jaeger all-in-one..."
    docker run -d --name jaeger-cdcs \
        -p 16686:16686 \
        -p 14250:14250 \
        jaegertracing/all-in-one:latest \
        --log-level=debug >/dev/null 2>&1 || true
    
    if docker ps | grep -q jaeger-cdcs; then
        success "Jaeger started successfully - UI available at http://localhost:16686"
    else
        warn "Failed to start Jaeger - traces will be stored locally"
    fi
}

# Start the collector
start_collector() {
    local collector_binary="$SCRIPT_DIR/otelcol"
    
    if check_running; then
        warn "OpenTelemetry Collector is already running (PID: $(cat "$PID_FILE"))"
        return 0
    fi
    
    if [[ ! -f "$collector_binary" ]]; then
        download_collector
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Start Jaeger first
    start_jaeger
    
    log "Starting OpenTelemetry Collector..."
    log "Config: $CONFIG_FILE"
    log "Logs: $LOG_FILE"
    
    # Start collector in background
    nohup "$collector_binary" --config="$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Wait a moment and check if it started successfully
    sleep 2
    if ps -p "$pid" > /dev/null 2>&1; then
        success "OpenTelemetry Collector started successfully (PID: $pid)"
        log "Endpoints available:"
        log "  - OTLP gRPC: localhost:4317"
        log "  - OTLP HTTP: localhost:4318"
        log "  - Prometheus metrics: localhost:8889"
        log "  - Collector metrics: localhost:8888"
        if docker ps | grep -q jaeger-cdcs; then
            log "  - Jaeger UI: http://localhost:16686"
        fi
        return 0
    else
        error "Failed to start OpenTelemetry Collector"
        error "Check logs: $LOG_FILE"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Stop the collector
stop_collector() {
    if check_running; then
        local pid=$(cat "$PID_FILE")
        log "Stopping OpenTelemetry Collector (PID: $pid)..."
        kill "$pid"
        rm -f "$PID_FILE"
        success "OpenTelemetry Collector stopped"
    else
        warn "OpenTelemetry Collector is not running"
    fi
    
    # Stop Jaeger if running
    if command -v docker >/dev/null 2>&1 && docker ps | grep -q jaeger-cdcs; then
        log "Stopping Jaeger..."
        docker stop jaeger-cdcs >/dev/null 2>&1 || true
        docker rm jaeger-cdcs >/dev/null 2>&1 || true
        success "Jaeger stopped"
    fi
}

# Show status
show_status() {
    echo "🔍 CDCS OpenTelemetry Status"
    echo "=========================="
    
    if check_running; then
        local pid=$(cat "$PID_FILE")
        success "OpenTelemetry Collector: Running (PID: $pid)"
        
        # Check endpoints
        if curl -s -f http://localhost:8888/metrics >/dev/null 2>&1; then
            success "Collector metrics endpoint: ✓ http://localhost:8888"
        else
            error "Collector metrics endpoint: ✗"
        fi
        
        if curl -s -f http://localhost:8889/metrics >/dev/null 2>&1; then
            success "Prometheus endpoint: ✓ http://localhost:8889"
        else
            warn "Prometheus endpoint: ✗ http://localhost:8889"
        fi
        
        # Check Jaeger
        if command -v docker >/dev/null 2>&1 && docker ps | grep -q jaeger-cdcs; then
            success "Jaeger UI: ✓ http://localhost:16686"
        else
            warn "Jaeger UI: ✗ (not running)"
        fi
        
    else
        error "OpenTelemetry Collector: Not running"
    fi
    
    echo ""
    echo "📊 Recent telemetry files:"
    find "$SCRIPT_DIR" -name "*.jsonl" -o -name "*.log" | head -5 | while read -r file; do
        echo "  📁 $file ($(wc -l < "$file" 2>/dev/null || echo 0) lines)"
    done
}

# Show logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "📋 Recent OpenTelemetry Collector logs:"
        echo "======================================="
        tail -20 "$LOG_FILE"
    else
        warn "No log file found: $LOG_FILE"
    fi
}

# Health check
health_check() {
    local endpoints=(
        "http://localhost:8888/metrics"
        "http://localhost:4318/v1/traces"
    )
    
    local healthy=true
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s -f "$endpoint" >/dev/null 2>&1; then
            success "✓ $endpoint"
        else
            error "✗ $endpoint"
            healthy=false
        fi
    done
    
    if $healthy; then
        success "All OpenTelemetry endpoints are healthy"
        return 0
    else
        error "Some OpenTelemetry endpoints are unhealthy"
        return 1
    fi
}

# Main command dispatcher
case "${1:-start}" in
    "start")
        start_collector
        ;;
    "stop")
        stop_collector
        ;;
    "restart")
        stop_collector
        sleep 1
        start_collector
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "health")
        health_check
        ;;
    "download")
        download_collector
        ;;
    *)
        echo "🔧 CDCS OpenTelemetry Collector Management"
        echo "Usage: $0 {start|stop|restart|status|logs|health|download}"
        echo ""
        echo "Commands:"
        echo "  start    - Start OpenTelemetry Collector and Jaeger"
        echo "  stop     - Stop OpenTelemetry Collector and Jaeger"  
        echo "  restart  - Restart OpenTelemetry Collector"
        echo "  status   - Show service status and endpoints"
        echo "  logs     - Show recent collector logs"
        echo "  health   - Check endpoint health"
        echo "  download - Download collector binary"
        ;;
esac
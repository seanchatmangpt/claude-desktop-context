#!/bin/bash
TELEMETRY_PATH="/Users/sac/claude-desktop-context/automation/telemetry"
cd "$TELEMETRY_PATH"

# Check if already running
if pgrep -f "otelcol.*cdcs" > /dev/null; then
    echo "OpenTelemetry Collector already running"
    exit 0
fi

# Start collector
echo "Starting OpenTelemetry Collector..."
nohup ./otelcol --config=otel-collector-config-simple.yaml > collector.log 2>&1 &
echo $! > collector.pid

# Wait for startup
sleep 2

# Check if running
if ps -p $(cat collector.pid) > /dev/null; then
    echo "✓ Collector started (PID: $(cat collector.pid))"
    echo "  - OTLP endpoint: localhost:4317"
    echo "  - Prometheus metrics: localhost:9090"
    echo "  - Health check: localhost:13133/health"
else
    echo "❌ Failed to start collector"
    exit 1
fi

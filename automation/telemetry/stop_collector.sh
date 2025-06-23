#!/bin/bash
TELEMETRY_PATH="/Users/sac/claude-desktop-context/automation/telemetry"
cd "$TELEMETRY_PATH"

if [ -f collector.pid ]; then
    PID=$(cat collector.pid)
    if ps -p $PID > /dev/null; then
        echo "Stopping OpenTelemetry Collector (PID: $PID)..."
        kill $PID
        sleep 2
        if ps -p $PID > /dev/null; then
            kill -9 $PID
        fi
        echo "✓ Collector stopped"
    else
        echo "Collector not running"
    fi
    rm -f collector.pid
else
    echo "No PID file found"
fi

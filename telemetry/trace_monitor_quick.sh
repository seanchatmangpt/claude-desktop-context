#!/bin/bash
# Quick trace monitor with timeout

echo "📊 OpenTelemetry Quick Status"
echo "============================"
echo ""

# Check if collector is running
if pgrep -f otelcol-contrib > /dev/null; then
    echo "✅ Collector: Running"
else
    echo "❌ Collector: Not running"
fi

# Show recent traces (with 5 second timeout)
if [ -f "/tmp/otel_traces.log" ]; then
    echo ""
    echo "Recent traces (last 5):"
    timeout 5s tail -5 /tmp/otel_traces.log 2>/dev/null || echo "No recent traces"
else
    echo "No trace log found"
fi

echo ""
echo "For continuous monitoring, use: make trace"
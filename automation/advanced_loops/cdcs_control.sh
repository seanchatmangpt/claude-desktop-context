#!/bin/bash
# CDCS Advanced Automation Master Control

CDCS_PATH="/Users/sac/claude-desktop-context"
AUTOMATION_PATH="$CDCS_PATH/automation"
ADVANCED_PATH="$AUTOMATION_PATH/advanced_loops"
TELEMETRY_PATH="$AUTOMATION_PATH/telemetry"

show_menu() {
    clear
    echo "╔══════════════════════════════════════════════════╗"
    echo "║        CDCS Advanced Automation Control          ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    echo "1. Start All Services"
    echo "2. Stop All Services"
    echo "3. Service Status"
    echo "4. View Dashboard"
    echo "5. Run Validation"
    echo "6. View Logs"
    echo "7. Telemetry Status"
    echo "8. Manual Component Trigger"
    echo "9. Configuration"
    echo "0. Exit"
    echo ""
}

start_all() {
    echo "Starting all services..."
    
    # Start OTEL Collector
    "$TELEMETRY_PATH/start_collector.sh"
    
    # Start telemetry aggregator
    if ! pgrep -f "aggregator.py" > /dev/null; then
        echo "Starting Telemetry Aggregator..."
        source "$AUTOMATION_PATH/telemetry.env"
        nohup python3 "$TELEMETRY_PATH/aggregator.py" > "$AUTOMATION_PATH/logs/telemetry_aggregator.log" 2>&1 &
        echo "✓ Telemetry Aggregator started"
    fi
    
    echo ""
    echo "All services started. Automation loops run via cron."
}

stop_all() {
    echo "Stopping all services..."
    
    # Stop OTEL Collector
    "$TELEMETRY_PATH/stop_collector.sh"
    
    # Stop aggregator
    pkill -f "aggregator.py"
    echo "✓ Telemetry Aggregator stopped"
    
    echo ""
    echo "Services stopped. Note: Cron jobs will continue running."
}

show_status() {
    echo "Service Status:"
    echo "═══════════════"
    
    # OTEL Collector
    if pgrep -f "otelcol.*cdcs" > /dev/null; then
        echo "✓ OpenTelemetry Collector: Running"
    else
        echo "✗ OpenTelemetry Collector: Stopped"
    fi
    
    # Telemetry Aggregator
    if pgrep -f "aggregator.py" > /dev/null; then
        echo "✓ Telemetry Aggregator: Running"
    else
        echo "✗ Telemetry Aggregator: Stopped"
    fi
    
    # Cron jobs
    CRON_COUNT=$(crontab -l 2>/dev/null | grep -c "CDCS_")
    echo "✓ Cron Jobs: $CRON_COUNT active"
    
    # Recent validations
    LATEST_VALIDATION=$(ls -t "$AUTOMATION_PATH/reports"/validation_*.md 2>/dev/null | head -1)
    if [ -n "$LATEST_VALIDATION" ]; then
        echo "✓ Last Validation: $(basename "$LATEST_VALIDATION")"
    fi
    
    echo ""
    # Health check
    if curl -s http://localhost:13133/health > /dev/null 2>&1; then
        echo "📊 Collector Health: OK"
    else
        echo "📊 Collector Health: Not responding"
    fi
}

view_dashboard() {
    echo "Opening telemetry dashboard..."
    source "$AUTOMATION_PATH/telemetry.env"
    python3 "$TELEMETRY_PATH/aggregator.py"
}

run_validation() {
    echo "Running validation suite..."
    source "$AUTOMATION_PATH/telemetry.env"
    python3 "$ADVANCED_PATH/validation_framework.py"
}

view_logs() {
    echo "Select log to view:"
    echo "1. Telemetry Aggregator"
    echo "2. OTEL Collector"
    echo "3. Validation"
    echo "4. All Automation Logs"
    read -p "Choice: " log_choice
    
    case $log_choice in
        1) tail -f "$AUTOMATION_PATH/logs/telemetry_aggregator.log" ;;
        2) tail -f "$TELEMETRY_PATH/collector.log" ;;
        3) tail -f "$AUTOMATION_PATH/logs/validation.log" ;;
        4) tail -f "$AUTOMATION_PATH/logs/"*.log ;;
    esac
}

telemetry_status() {
    echo "Telemetry Status:"
    echo "════════════════"
    
    # Check endpoints
    echo ""
    echo "Endpoints:"
    echo "  OTLP: localhost:4317"
    echo "  Prometheus: localhost:9090"
    echo "  Health: localhost:13133/health"
    echo "  zPages: localhost:55679"
    
    # Check data
    if [ -f "$TELEMETRY_PATH/traces.json" ]; then
        TRACE_SIZE=$(du -h "$TELEMETRY_PATH/traces.json" | cut -f1)
        echo ""
        echo "Trace Data: $TRACE_SIZE"
    fi
    
    # Recent metrics
    if [ -f "$TELEMETRY_PATH/aggregated_metrics.db" ]; then
        DB_SIZE=$(du -h "$TELEMETRY_PATH/aggregated_metrics.db" | cut -f1)
        echo "Metrics DB: $DB_SIZE"
    fi
}

# Main loop
while true; do
    show_menu
    read -p "Select option: " choice
    
    case $choice in
        1) start_all ;;
        2) stop_all ;;
        3) show_status ;;
        4) view_dashboard ;;
        5) run_validation ;;
        6) view_logs ;;
        7) telemetry_status ;;
        8) "$ADVANCED_PATH/manual_trigger.sh" ;;
        9) nano "$ADVANCED_PATH/rules/default_rules.json" ;;
        0) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done

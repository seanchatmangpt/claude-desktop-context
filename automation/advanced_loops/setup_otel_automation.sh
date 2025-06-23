#!/bin/bash
# CDCS Advanced Automation with OpenTelemetry - Complete Setup
# Integrates telemetry, validation, and enhanced automation loops

CDCS_PATH="/Users/sac/claude-desktop-context"
AUTOMATION_PATH="$CDCS_PATH/automation"
ADVANCED_PATH="$AUTOMATION_PATH/advanced_loops"
TELEMETRY_PATH="$AUTOMATION_PATH/telemetry"
PYTHON_PATH="/usr/bin/python3"

echo "🚀 CDCS Advanced Automation + OpenTelemetry Setup"
echo "================================================"

# Check Python version
echo "📐 Checking Python version..."
PYTHON_VERSION=$($PYTHON_PATH --version 2>&1 | cut -d' ' -f2)
echo "   Python version: $PYTHON_VERSION"

# Install required Python packages
echo "📦 Installing Python dependencies..."
pip3 install --quiet \
    opentelemetry-api \
    opentelemetry-sdk \
    opentelemetry-instrumentation \
    opentelemetry-exporter-otlp \
    opentelemetry-exporter-jaeger \
    opentelemetry-exporter-prometheus \
    psutil \
    matplotlib \
    2>/dev/null

# Check installation status
if pip3 show opentelemetry-api >/dev/null 2>&1; then
    echo "   ✓ OpenTelemetry packages installed"
else
    echo "   ⚠️  Some packages may be missing - install manually if needed"
fi

# Create necessary directories
echo "📁 Creating directory structure..."
mkdir -p "$TELEMETRY_PATH/data"
mkdir -p "$TELEMETRY_PATH/exports"
mkdir -p "$AUTOMATION_PATH/reports"
mkdir -p "$ADVANCED_PATH/rules"

# Download OpenTelemetry Collector if not present
echo "📥 Setting up OpenTelemetry Collector..."
OTEL_VERSION="0.91.0"
OTEL_BINARY="otelcol"

if [ ! -f "$TELEMETRY_PATH/$OTEL_BINARY" ]; then
    echo "   Downloading OpenTelemetry Collector..."
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        ARCH="arm64"
    fi
    
    DOWNLOAD_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol_${OTEL_VERSION}_${OS}_${ARCH}.tar.gz"
    
    curl -L -o "$TELEMETRY_PATH/otelcol.tar.gz" "$DOWNLOAD_URL" 2>/dev/null
    
    if [ -f "$TELEMETRY_PATH/otelcol.tar.gz" ]; then
        tar -xzf "$TELEMETRY_PATH/otelcol.tar.gz" -C "$TELEMETRY_PATH" otelcol
        rm "$TELEMETRY_PATH/otelcol.tar.gz"
        chmod +x "$TELEMETRY_PATH/$OTEL_BINARY"
        echo "   ✓ OpenTelemetry Collector downloaded"
    else
        echo "   ⚠️  Failed to download collector - manual installation required"
    fi
else
    echo "   ✓ OpenTelemetry Collector already present"
fi

# Create systemd-style service scripts
echo "🔧 Creating service management scripts..."

# OTEL Collector service
cat > "$TELEMETRY_PATH/start_collector.sh" << 'EOF'
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
nohup ./otelcol --config=otel-collector-config.yaml > collector.log 2>&1 &
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
EOF

chmod +x "$TELEMETRY_PATH/start_collector.sh"

# Create stop script
cat > "$TELEMETRY_PATH/stop_collector.sh" << 'EOF'
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
EOF

chmod +x "$TELEMETRY_PATH/stop_collector.sh"

# Update automation scripts to use OpenTelemetry
echo "🔄 Updating automation scripts for OpenTelemetry..."

# Create environment configuration
cat > "$AUTOMATION_PATH/telemetry.env" << EOF
# OpenTelemetry Configuration for CDCS
export CDCS_TELEMETRY_ENABLED=true
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_SERVICE_NAME=cdcs-automation
export OTEL_SERVICE_VERSION=2.1.0
export CDCS_ENV=production
export OTEL_METRIC_EXPORT_INTERVAL=30000
export OTEL_TRACES_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
EOF

# Update cron jobs to source telemetry environment
echo "⏰ Updating cron jobs with telemetry..."

# Function to update cron with telemetry
update_cron_with_telemetry() {
    local temp_cron=$(mktemp)
    crontab -l > "$temp_cron" 2>/dev/null || true
    
    # Add source line if not present
    if ! grep -q "telemetry.env" "$temp_cron"; then
        # Add at the beginning after any existing PATH or env vars
        sed -i '' '1s/^/# Source OpenTelemetry configuration\n/' "$temp_cron"
        sed -i '' '2s/^/. \/Users\/sac\/claude-desktop-context\/automation\/telemetry.env\n\n/' "$temp_cron"
    fi
    
    crontab "$temp_cron"
    rm "$temp_cron"
}

update_cron_with_telemetry

# Add telemetry aggregator to cron
add_cron_job() {
    local schedule="$1"
    local command="$2"
    local job_id="$3"
    
    if ! crontab -l 2>/dev/null | grep -q "$job_id"; then
        (crontab -l 2>/dev/null; echo "$schedule $command # $job_id") | crontab -
        echo "   ✓ Added $job_id"
    else
        echo "   ✓ $job_id already scheduled"
    fi
}

# Telemetry Aggregator - runs continuously but checked every 5 minutes
add_cron_job \
    "*/5 * * * *" \
    "pgrep -f 'aggregator.py' || $PYTHON_PATH $TELEMETRY_PATH/aggregator.py >> $AUTOMATION_PATH/logs/telemetry_aggregator.log 2>&1 &" \
    "CDCS_TELEMETRY_AGGREGATOR"

# Validation Framework - runs every 6 hours
add_cron_job \
    "0 */6 * * *" \
    ". $AUTOMATION_PATH/telemetry.env && $PYTHON_PATH $ADVANCED_PATH/validation_framework.py >> $AUTOMATION_PATH/logs/validation.log 2>&1" \
    "CDCS_VALIDATION"

# Create master control script
echo "🎮 Creating master control script..."
cat > "$ADVANCED_PATH/cdcs_control.sh" << 'EOF'
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
EOF

chmod +x "$ADVANCED_PATH/cdcs_control.sh"

# Create quick start guide
cat > "$ADVANCED_PATH/QUICKSTART.md" << 'EOF'
# CDCS Advanced Automation + OpenTelemetry Quick Start

## 🚀 Quick Commands

### Start Everything
```bash
./cdcs_control.sh
# Select option 1
```

### View Real-time Dashboard
```bash
./cdcs_control.sh
# Select option 4
```

### Check System Health
```bash
./cdcs_control.sh
# Select option 5 (Run Validation)
```

## 📊 Telemetry Endpoints

- **OTLP**: `localhost:4317` - Send traces and metrics here
- **Prometheus**: `localhost:9090` - Scrape metrics
- **Health Check**: `localhost:13133/health` - Collector health
- **zPages**: `localhost:55679` - Debug interface

## 🔧 Configuration

### Enable/Disable Telemetry
Edit `automation/telemetry.env`:
```bash
export CDCS_TELEMETRY_ENABLED=true  # or false
```

### Customize Alerts
Edit `automation/advanced_loops/rules/default_rules.json`

### Adjust Cron Schedules
```bash
crontab -e
# Edit CDCS_* job schedules
```

## 📈 Monitoring

### View Metrics
1. Prometheus: http://localhost:9090
2. Text Dashboard: Run aggregator
3. Logs: `automation/logs/`

### Key Metrics to Watch
- `cdcs.agent.executions` - Agent activity
- `cdcs.patterns.detected` - Pattern discovery rate
- `cdcs.fixes.applied` - Self-healing activity
- `cdcs.system.health` - Overall health score

## 🛠️ Troubleshooting

### Collector Not Starting
```bash
# Check logs
cat automation/telemetry/collector.log

# Verify config
./otelcol validate --config=otel-collector-config.yaml
```

### No Metrics Appearing
```bash
# Check telemetry is enabled
grep ENABLED automation/telemetry.env

# Verify endpoints
curl http://localhost:13133/health
```

### High Memory Usage
- Adjust `memory_limiter` in collector config
- Reduce metric retention in aggregator

## 🎯 Best Practices

1. **Monitor Regularly**: Check validation reports weekly
2. **Act on Alerts**: Don't ignore critical alerts
3. **Review Patterns**: Check discovered patterns monthly
4. **Optimize Schedules**: Let the system learn optimal times
5. **Clean Logs**: Rotate logs to save disk space

---

For detailed documentation, see the README files in each component directory.
EOF

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📚 What's New:"
echo "   • OpenTelemetry instrumentation for all components"
echo "   • Real-time telemetry dashboard"
echo "   • Comprehensive validation framework"
echo "   • Unified control interface"
echo ""
echo "🎯 Next Steps:"
echo "   1. Start services: $ADVANCED_PATH/cdcs_control.sh"
echo "   2. Choose option 1 to start all services"
echo "   3. Choose option 4 to view the dashboard"
echo ""
echo "📊 Telemetry will be available at:"
echo "   • OTLP: localhost:4317"
echo "   • Prometheus: localhost:9090"
echo "   • Health: localhost:13133/health"
echo ""
echo "🔍 For detailed monitoring, you can also install:"
echo "   • Jaeger UI: docker run -p 16686:16686 jaegertracing/all-in-one"
echo "   • Grafana: docker run -p 3000:3000 grafana/grafana"
echo ""
echo "Happy automating with full observability! 🚀"

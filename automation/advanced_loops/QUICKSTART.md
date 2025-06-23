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

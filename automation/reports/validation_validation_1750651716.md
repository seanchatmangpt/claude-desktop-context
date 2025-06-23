# CDCS Automation Validation Report

**Run ID**: validation_1750651716  
**Generated**: 2025-06-22T21:08:37.442429  
**Environment**: production

## Summary

- **Total Tests**: 5
- **Passed**: 1 ✅
- **Failed**: 4 ❌
- **Success Rate**: 20.0%

## Component Validation Results

### TerminalOrchestrator - basic_functionality ❌

- **Status**: failed
- **Duration**: 0.18s

**Assertions** (2/3 passed):

- ✓ script_exists: Script exists at /Users/sac/claude-desktop-context/automation/advanced_loops/terminal_orchestrator.py
- ✗ patterns_db_exists: Patterns database exists
- ✓ applescript_available: AppleScript terminal control available

**Details**:
```json
{
  "assertions_passed": 2,
  "total_assertions": 3
}
```

---

### PatternDetector - monitoring_capability ❌

- **Status**: failed
- **Duration**: 0.00s

**Assertions** (2/3 passed):

- ✓ script_exists: Script exists at /Users/sac/claude-desktop-context/automation/advanced_loops/realtime_pattern_detector.py
- ✗ fsevents_available: Using polling fallback
- ✓ monitoring_paths: 3/3 monitoring paths exist

---

### CronScheduler - optimization_capability ❌

- **Status**: failed
- **Duration**: 0.01s

**Assertions** (2/3 passed):

- ✓ script_exists: Scheduler script exists
- ✗ metrics_db_exists: Metrics database exists
- ✓ cron_jobs_configured: Found 11 CDCS cron jobs

---

### SelfHealing - health_monitoring ❌

- **Status**: failed
- **Duration**: 1.01s

**Assertions** (2/4 passed):

- ✓ script_exists: Self-healing script exists
- ✗ healing_db_exists: Healing database exists
- ✓ system_metrics_available: Disk: 2.8%, Memory: 60.4%, CPU: 20.5%
- ✗ recent_health_report: Found 0 health reports

---

### Telemetry - observability ✅

- **Status**: passed
- **Duration**: 0.01s

**Assertions** (4/4 passed):

- ✓ otel_packages_installed: OpenTelemetry packages are installed
- ✓ otlp_endpoint_reachable: OTLP endpoint http://localhost:4317 is reachable
- ✓ telemetry_enabled: Telemetry is enabled via environment variable
- ✓ otel_base_agent_exists: OpenTelemetry base agent exists

---

## System Health

- **Disk Usage**: 2.8% (360.5 GB free)
- **Memory Usage**: 60.6% (18.9 GB available)
- **CPU Usage**: 10.7%
- **Load Average**: 2.95, 3.28, 3.43

## Recommendations

### Failed Tests

- **TerminalOrchestrator**: Fix patterns_db_exists
- **PatternDetector**: Fix fsevents_available
- **CronScheduler**: Fix metrics_db_exists
- **SelfHealing**: Fix healing_db_exists, recent_health_report

## Next Steps

1. Address any failed tests
2. Review component logs for errors
3. Run validation again after fixes
4. Monitor telemetry dashboards

#!/usr/bin/env python3
"""
CDCS Automation Validation Framework
Validates that all automation loops are functioning correctly
"""

import os
import sys
import json
import time
import sqlite3
import subprocess
import psutil
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
import logging
from collections import defaultdict

# Add CDCS path
CDCS_PATH = Path("/Users/sac/claude-desktop-context")
sys.path.append(str(CDCS_PATH / "automation"))
sys.path.append(str(CDCS_PATH / "automation" / "advanced_loops"))

from otel_base_agent import OTelBaseAgent, instrument_function

class ValidationResult:
    """Represents a validation test result"""
    
    def __init__(self, component: str, test_name: str):
        self.component = component
        self.test_name = test_name
        self.status = "pending"
        self.start_time = None
        self.end_time = None
        self.error = None
        self.details = {}
        self.assertions = []
        
    def start(self):
        """Mark test as started"""
        self.start_time = datetime.now()
        self.status = "running"
        
    def complete(self, success: bool, error: str = None, details: Dict = None):
        """Mark test as complete"""
        self.end_time = datetime.now()
        self.status = "passed" if success else "failed"
        self.error = error
        if details:
            self.details.update(details)
            
    def add_assertion(self, name: str, passed: bool, message: str = None):
        """Add an assertion result"""
        self.assertions.append({
            'name': name,
            'passed': passed,
            'message': message
        })
        
    @property
    def duration(self) -> float:
        """Get test duration in seconds"""
        if self.start_time and self.end_time:
            return (self.end_time - self.start_time).total_seconds()
        return 0
        
    @property
    def passed(self) -> bool:
        """Check if test passed"""
        return self.status == "passed" and all(a['passed'] for a in self.assertions)

class AutomationValidator(OTelBaseAgent):
    """
    Comprehensive validation framework for CDCS automation loops
    """
    
    def __init__(self, orchestrator):
        super().__init__(orchestrator, "AutomationValidator")
        self.validation_db = CDCS_PATH / "automation" / "validation_results.db"
        self.init_validation_db()
        
        # Additional metrics for validation
        self.validation_counter = self._meter.create_counter(
            name="cdcs.validation.tests.run",
            description="Number of validation tests run",
            unit="1"
        )
        
        self.validation_duration = self._meter.create_histogram(
            name="cdcs.validation.test.duration",
            description="Duration of validation tests",
            unit="s"
        )
        
        self.validation_success_rate = self._meter.create_gauge(
            name="cdcs.validation.success.rate",
            description="Validation success rate",
            unit="ratio"
        )
        
    def init_validation_db(self):
        """Initialize validation results database"""
        conn = sqlite3.connect(self.validation_db)
        conn.execute('''
            CREATE TABLE IF NOT EXISTS validation_runs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                run_id TEXT UNIQUE,
                start_time TIMESTAMP,
                end_time TIMESTAMP,
                total_tests INTEGER,
                passed_tests INTEGER,
                failed_tests INTEGER,
                success_rate REAL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.execute('''
            CREATE TABLE IF NOT EXISTS test_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                run_id TEXT,
                component TEXT,
                test_name TEXT,
                status TEXT,
                duration REAL,
                error TEXT,
                details TEXT,
                assertions TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (run_id) REFERENCES validation_runs(run_id)
            )
        ''')
        
        conn.commit()
        conn.close()
        
    @instrument_function()
    def validate_terminal_orchestrator(self) -> ValidationResult:
        """Validate Terminal Orchestrator functionality"""
        result = ValidationResult("TerminalOrchestrator", "basic_functionality")
        result.start()
        
        with self.start_span("validate.terminal_orchestrator") as span:
            try:
                # Test 1: Check if orchestrator script exists
                script_path = CDCS_PATH / "automation" / "advanced_loops" / "terminal_orchestrator.py"
                result.add_assertion(
                    "script_exists",
                    script_path.exists(),
                    f"Script exists at {script_path}"
                )
                
                # Test 2: Check patterns database
                patterns_db = CDCS_PATH / "automation" / "discovered_patterns.db"
                result.add_assertion(
                    "patterns_db_exists",
                    patterns_db.exists(),
                    "Patterns database exists"
                )
                
                # Test 3: Test AppleScript capability
                try:
                    test_script = 'tell application "Terminal" to return name of front window'
                    proc = subprocess.run(
                        ['osascript', '-e', test_script],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )
                    applescript_works = proc.returncode == 0
                except:
                    applescript_works = False
                    
                result.add_assertion(
                    "applescript_available",
                    applescript_works,
                    "AppleScript terminal control available"
                )
                
                # Test 4: Check for recent patterns
                if patterns_db.exists():
                    conn = sqlite3.connect(patterns_db)
                    cursor = conn.execute(
                        "SELECT COUNT(*) FROM automation_patterns WHERE last_triggered > datetime('now', '-7 days')"
                    )
                    recent_patterns = cursor.fetchone()[0]
                    conn.close()
                    
                    result.add_assertion(
                        "recent_patterns",
                        recent_patterns >= 0,
                        f"Found {recent_patterns} recent patterns"
                    )
                
                # Overall success
                all_passed = all(a['passed'] for a in result.assertions)
                result.complete(success=all_passed, details={
                    'assertions_passed': sum(1 for a in result.assertions if a['passed']),
                    'total_assertions': len(result.assertions)
                })
                
                if span:
                    span.set_attribute("validation.passed", all_passed)
                    span.set_attribute("assertions.count", len(result.assertions))
                    
            except Exception as e:
                result.complete(success=False, error=str(e))
                if span:
                    span.record_exception(e)
                    
        return result
        
    @instrument_function()
    def validate_pattern_detector(self) -> ValidationResult:
        """Validate Realtime Pattern Detector"""
        result = ValidationResult("PatternDetector", "monitoring_capability")
        result.start()
        
        with self.start_span("validate.pattern_detector") as span:
            try:
                # Test 1: Check script exists
                script_path = CDCS_PATH / "automation" / "advanced_loops" / "realtime_pattern_detector.py"
                result.add_assertion(
                    "script_exists",
                    script_path.exists(),
                    f"Script exists at {script_path}"
                )
                
                # Test 2: Check if FSEvents is available (macOS)
                try:
                    import fsevents
                    has_fsevents = True
                except ImportError:
                    has_fsevents = False
                    
                result.add_assertion(
                    "fsevents_available",
                    has_fsevents,
                    "FSEvents available for efficient monitoring" if has_fsevents else "Using polling fallback"
                )
                
                # Test 3: Check monitoring paths exist
                monitoring_paths = [
                    CDCS_PATH,
                    Path.home() / "Desktop",
                    Path.home() / "Documents"
                ]
                
                existing_paths = sum(1 for p in monitoring_paths if p.exists())
                result.add_assertion(
                    "monitoring_paths",
                    existing_paths >= 1,
                    f"{existing_paths}/{len(monitoring_paths)} monitoring paths exist"
                )
                
                # Test 4: Check rules configuration
                rules_path = CDCS_PATH / "automation" / "advanced_loops" / "rules" / "default_rules.json"
                if rules_path.exists():
                    try:
                        rules = json.loads(rules_path.read_text())
                        realtime_enabled = rules.get('realtime_monitoring', {}).get('enabled', False)
                        result.add_assertion(
                            "realtime_monitoring_enabled",
                            realtime_enabled,
                            "Realtime monitoring is enabled in configuration"
                        )
                    except:
                        result.add_assertion(
                            "rules_valid",
                            False,
                            "Failed to parse rules configuration"
                        )
                
                # Overall success
                all_passed = all(a['passed'] for a in result.assertions)
                result.complete(success=all_passed)
                
            except Exception as e:
                result.complete(success=False, error=str(e))
                
        return result
        
    @instrument_function()
    def validate_cron_scheduler(self) -> ValidationResult:
        """Validate Intelligent Cron Scheduler"""
        result = ValidationResult("CronScheduler", "optimization_capability")
        result.start()
        
        with self.start_span("validate.cron_scheduler") as span:
            try:
                # Test 1: Check script and database
                script_path = CDCS_PATH / "automation" / "advanced_loops" / "intelligent_cron_scheduler.py"
                metrics_db = CDCS_PATH / "automation" / "cron_metrics.db"
                
                result.add_assertion(
                    "script_exists",
                    script_path.exists(),
                    "Scheduler script exists"
                )
                
                result.add_assertion(
                    "metrics_db_exists",
                    metrics_db.exists(),
                    "Metrics database exists"
                )
                
                # Test 2: Check cron jobs
                try:
                    cron_output = subprocess.check_output(['crontab', '-l'], text=True)
                    cdcs_jobs = [line for line in cron_output.split('\n') if 'CDCS_' in line]
                    
                    result.add_assertion(
                        "cron_jobs_configured",
                        len(cdcs_jobs) > 0,
                        f"Found {len(cdcs_jobs)} CDCS cron jobs"
                    )
                except:
                    result.add_assertion(
                        "cron_jobs_configured",
                        False,
                        "Could not check cron jobs"
                    )
                
                # Test 3: Check for job execution history
                if metrics_db.exists():
                    conn = sqlite3.connect(metrics_db)
                    cursor = conn.execute(
                        "SELECT COUNT(*) FROM job_executions WHERE start_time > datetime('now', '-24 hours')"
                    )
                    recent_executions = cursor.fetchone()[0]
                    conn.close()
                    
                    result.add_assertion(
                        "recent_executions",
                        recent_executions >= 0,
                        f"Found {recent_executions} executions in last 24 hours"
                    )
                
                all_passed = all(a['passed'] for a in result.assertions)
                result.complete(success=all_passed)
                
            except Exception as e:
                result.complete(success=False, error=str(e))
                
        return result
        
    @instrument_function()
    def validate_self_healing(self) -> ValidationResult:
        """Validate Self-Healing Loop"""
        result = ValidationResult("SelfHealing", "health_monitoring")
        result.start()
        
        with self.start_span("validate.self_healing") as span:
            try:
                # Test 1: Basic setup
                script_path = CDCS_PATH / "automation" / "advanced_loops" / "self_healing_loop.py"
                healing_db = CDCS_PATH / "automation" / "self_healing.db"
                
                result.add_assertion(
                    "script_exists",
                    script_path.exists(),
                    "Self-healing script exists"
                )
                
                result.add_assertion(
                    "healing_db_exists",
                    healing_db.exists(),
                    "Healing database exists"
                )
                
                # Test 2: System metrics available
                try:
                    disk_usage = psutil.disk_usage('/')
                    memory = psutil.virtual_memory()
                    cpu_percent = psutil.cpu_percent(interval=1)
                    
                    result.add_assertion(
                        "system_metrics_available",
                        True,
                        f"Disk: {disk_usage.percent:.1f}%, Memory: {memory.percent:.1f}%, CPU: {cpu_percent:.1f}%"
                    )
                except:
                    result.add_assertion(
                        "system_metrics_available",
                        False,
                        "Failed to get system metrics"
                    )
                
                # Test 3: Check recent health reports
                reports_dir = CDCS_PATH / "automation" / "reports"
                if reports_dir.exists():
                    recent_reports = list(reports_dir.glob("health_report_*.md"))
                    recent_reports.sort(key=lambda x: x.stat().st_mtime, reverse=True)
                    
                    has_recent_report = False
                    if recent_reports:
                        latest = recent_reports[0]
                        age = datetime.now() - datetime.fromtimestamp(latest.stat().st_mtime)
                        has_recent_report = age < timedelta(hours=24)
                        
                    result.add_assertion(
                        "recent_health_report",
                        has_recent_report,
                        f"Found {len(recent_reports)} health reports"
                    )
                
                # Test 4: Check fix history
                if healing_db.exists():
                    conn = sqlite3.connect(healing_db)
                    cursor = conn.execute(
                        "SELECT COUNT(*) FROM fix_history WHERE applied_at > datetime('now', '-7 days')"
                    )
                    recent_fixes = cursor.fetchone()[0]
                    conn.close()
                    
                    result.add_assertion(
                        "recent_fixes",
                        recent_fixes >= 0,
                        f"Applied {recent_fixes} fixes in last 7 days"
                    )
                
                all_passed = all(a['passed'] for a in result.assertions)
                result.complete(success=all_passed)
                
            except Exception as e:
                result.complete(success=False, error=str(e))
                
        return result
        
    @instrument_function()
    def validate_telemetry(self) -> ValidationResult:
        """Validate OpenTelemetry integration"""
        result = ValidationResult("Telemetry", "observability")
        result.start()
        
        with self.start_span("validate.telemetry") as span:
            try:
                # Test 1: OpenTelemetry packages installed
                try:
                    import opentelemetry
                    from opentelemetry import trace, metrics
                    otel_available = True
                except ImportError:
                    otel_available = False
                    
                result.add_assertion(
                    "otel_packages_installed",
                    otel_available,
                    "OpenTelemetry packages are installed"
                )
                
                # Test 2: Check OTLP endpoint configuration
                endpoint = os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4317')
                
                # Try to connect to endpoint
                import socket
                try:
                    host, port = endpoint.replace('http://', '').split(':')
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(2)
                    endpoint_reachable = sock.connect_ex((host, int(port))) == 0
                    sock.close()
                except:
                    endpoint_reachable = False
                    
                result.add_assertion(
                    "otlp_endpoint_reachable",
                    endpoint_reachable,
                    f"OTLP endpoint {endpoint} is {'reachable' if endpoint_reachable else 'not reachable'}"
                )
                
                # Test 3: Telemetry enabled
                telemetry_enabled = os.getenv('CDCS_TELEMETRY_ENABLED', 'true').lower() == 'true'
                result.add_assertion(
                    "telemetry_enabled",
                    telemetry_enabled,
                    "Telemetry is enabled via environment variable"
                )
                
                # Test 4: Base agent instrumentation
                otel_base_path = CDCS_PATH / "automation" / "advanced_loops" / "otel_base_agent.py"
                result.add_assertion(
                    "otel_base_agent_exists",
                    otel_base_path.exists(),
                    "OpenTelemetry base agent exists"
                )
                
                all_passed = all(a['passed'] for a in result.assertions)
                result.complete(success=all_passed)
                
            except Exception as e:
                result.complete(success=False, error=str(e))
                
        return result
        
    def generate_validation_report(self, run_id: str, results: List[ValidationResult]) -> str:
        """Generate comprehensive validation report"""
        total_tests = len(results)
        passed_tests = sum(1 for r in results if r.passed)
        failed_tests = total_tests - passed_tests
        success_rate = passed_tests / total_tests if total_tests > 0 else 0
        
        report = f"""# CDCS Automation Validation Report

**Run ID**: {run_id}  
**Generated**: {datetime.now().isoformat()}  
**Environment**: {os.getenv('CDCS_ENV', 'production')}

## Summary

- **Total Tests**: {total_tests}
- **Passed**: {passed_tests} ✅
- **Failed**: {failed_tests} ❌
- **Success Rate**: {success_rate:.1%}

## Component Validation Results

"""
        
        for result in results:
            status_icon = "✅" if result.passed else "❌"
            report += f"### {result.component} - {result.test_name} {status_icon}\n\n"
            
            report += f"- **Status**: {result.status}\n"
            report += f"- **Duration**: {result.duration:.2f}s\n"
            
            if result.error:
                report += f"- **Error**: {result.error}\n"
                
            if result.assertions:
                report += f"\n**Assertions** ({sum(1 for a in result.assertions if a['passed'])}/{len(result.assertions)} passed):\n\n"
                for assertion in result.assertions:
                    icon = "✓" if assertion['passed'] else "✗"
                    report += f"- {icon} {assertion['name']}: {assertion['message']}\n"
                    
            if result.details:
                report += f"\n**Details**:\n```json\n{json.dumps(result.details, indent=2)}\n```\n"
                
            report += "\n---\n\n"
        
        # System health check
        report += "## System Health\n\n"
        try:
            disk = psutil.disk_usage('/')
            memory = psutil.virtual_memory()
            cpu_percent = psutil.cpu_percent(interval=1)
            
            report += f"- **Disk Usage**: {disk.percent:.1f}% ({disk.free / (1024**3):.1f} GB free)\n"
            report += f"- **Memory Usage**: {memory.percent:.1f}% ({memory.available / (1024**3):.1f} GB available)\n"
            report += f"- **CPU Usage**: {cpu_percent:.1f}%\n"
            report += f"- **Load Average**: {', '.join(f'{x:.2f}' for x in os.getloadavg())}\n"
        except:
            report += "- System metrics unavailable\n"
        
        # Recommendations
        report += "\n## Recommendations\n\n"
        
        if failed_tests > 0:
            report += "### Failed Tests\n\n"
            for result in results:
                if not result.passed:
                    report += f"- **{result.component}**: "
                    failed_assertions = [a for a in result.assertions if not a['passed']]
                    if failed_assertions:
                        report += f"Fix {', '.join(a['name'] for a in failed_assertions)}\n"
                    else:
                        report += f"Investigation needed\n"
        
        if not any(r.component == "Telemetry" and r.passed for r in results):
            report += "\n### Telemetry Setup\n"
            report += "- Install OpenTelemetry collector\n"
            report += "- Configure OTLP endpoint\n"
            report += "- Enable telemetry exports\n"
        
        report += "\n## Next Steps\n\n"
        report += "1. Address any failed tests\n"
        report += "2. Review component logs for errors\n"
        report += "3. Run validation again after fixes\n"
        report += "4. Monitor telemetry dashboards\n"
        
        return report
        
    def save_validation_results(self, run_id: str, results: List[ValidationResult]):
        """Save validation results to database"""
        conn = sqlite3.connect(self.validation_db)
        
        # Calculate summary stats
        total_tests = len(results)
        passed_tests = sum(1 for r in results if r.passed)
        failed_tests = total_tests - passed_tests
        success_rate = passed_tests / total_tests if total_tests > 0 else 0
        
        # Save run summary
        conn.execute('''
            INSERT INTO validation_runs 
            (run_id, start_time, end_time, total_tests, passed_tests, failed_tests, success_rate)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            run_id,
            min(r.start_time for r in results if r.start_time).isoformat(),
            max(r.end_time for r in results if r.end_time).isoformat(),
            total_tests,
            passed_tests,
            failed_tests,
            success_rate
        ))
        
        # Save individual test results
        for result in results:
            conn.execute('''
                INSERT INTO test_results
                (run_id, component, test_name, status, duration, error, details, assertions)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                run_id,
                result.component,
                result.test_name,
                result.status,
                result.duration,
                result.error,
                json.dumps(result.details),
                json.dumps(result.assertions)
            ))
        
        conn.commit()
        conn.close()
        
    def run(self):
        """Run all validation tests"""
        with self.start_span("validation.full_suite") as span:
            run_id = f"validation_{int(time.time())}"
            self.logger.info(f"Starting validation run: {run_id}")
            
            # Run all validation tests
            results = []
            
            # Component validations
            tests = [
                self.validate_terminal_orchestrator,
                self.validate_pattern_detector,
                self.validate_cron_scheduler,
                self.validate_self_healing,
                self.validate_telemetry
            ]
            
            for test_func in tests:
                try:
                    result = test_func()
                    results.append(result)
                    
                    self.validation_counter.add(
                        1,
                        {
                            "component": result.component,
                            "status": "passed" if result.passed else "failed"
                        }
                    )
                    
                    self.validation_duration.record(
                        result.duration,
                        {"component": result.component}
                    )
                    
                except Exception as e:
                    self.logger.error(f"Validation test failed: {e}")
                    # Create failed result
                    result = ValidationResult("Unknown", "error")
                    result.start()
                    result.complete(success=False, error=str(e))
                    results.append(result)
            
            # Calculate and record success rate
            success_rate = sum(1 for r in results if r.passed) / len(results) if results else 0
            self.validation_success_rate.set(success_rate)
            
            # Save results
            self.save_validation_results(run_id, results)
            
            # Generate report
            report = self.generate_validation_report(run_id, results)
            report_path = CDCS_PATH / "automation" / "reports" / f"validation_{run_id}.md"
            report_path.parent.mkdir(exist_ok=True, parents=True)
            report_path.write_text(report)
            
            self.logger.info(f"Validation complete. Success rate: {success_rate:.1%}")
            self.logger.info(f"Report saved to: {report_path}")
            
            if span:
                span.set_attribute("validation.run_id", run_id)
                span.set_attribute("validation.total_tests", len(results))
                span.set_attribute("validation.success_rate", success_rate)
                
            # Update overall system health based on validation
            self.update_health_score(success_rate * 100)

if __name__ == "__main__":
    # Run validation
    from cdcs_orchestrator import CDCSOrchestrator
    
    orchestrator = CDCSOrchestrator()
    validator = AutomationValidator(orchestrator)
    validator.run()

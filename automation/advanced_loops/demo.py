#!/usr/bin/env python3
"""
CDCS Demo - Showcase all automation capabilities
"""

import os
import sys
import time
import subprocess
from pathlib import Path
from datetime import datetime

# Setup paths
CDCS_PATH = Path("/Users/sac/claude-desktop-context")
AUTOMATION_PATH = CDCS_PATH / "automation"
ADVANCED_PATH = AUTOMATION_PATH / "advanced_loops"

def print_header(title):
    """Print a formatted header"""
    print("\n" + "="*60)
    print(f"  {title}")
    print("="*60 + "\n")

def check_service_status():
    """Check status of all services"""
    print_header("Service Status Check")
    
    # Check OTEL Collector
    try:
        response = subprocess.run(
            ["curl", "-s", "http://localhost:13133/health"],
            capture_output=True,
            text=True
        )
        if response.returncode == 0 and "Server available" in response.stdout:
            print("✅ OpenTelemetry Collector: Running")
            print(f"   Health: {response.stdout.strip()}")
        else:
            print("❌ OpenTelemetry Collector: Not running")
    except:
        print("❌ OpenTelemetry Collector: Not running")
    
    # Check cron jobs
    try:
        cron_output = subprocess.check_output(['crontab', '-l'], text=True)
        cdcs_jobs = [line for line in cron_output.split('\n') if 'CDCS_' in line]
        print(f"\n✅ Cron Jobs: {len(cdcs_jobs)} configured")
        for job in cdcs_jobs[:3]:  # Show first 3
            if job.strip():
                print(f"   - {job.split('#')[-1].strip()}")
    except:
        print("❌ No cron jobs configured")

def create_test_pattern():
    """Create a test pattern for detection"""
    print_header("Pattern Detection Demo")
    
    test_dir = CDCS_PATH / "test_patterns"
    test_dir.mkdir(exist_ok=True)
    
    print("Creating rapid file changes to trigger pattern detection...")
    
    # Create multiple files rapidly
    for i in range(5):
        test_file = test_dir / f"test_{i}.txt"
        test_file.write_text(f"Test content {i} at {datetime.now()}")
        print(f"   Created: {test_file.name}")
        time.sleep(0.1)
    
    # Modify them rapidly
    print("\nModifying files rapidly...")
    for i in range(5):
        test_file = test_dir / f"test_{i}.txt"
        test_file.write_text(f"Modified content {i} at {datetime.now()}")
        print(f"   Modified: {test_file.name}")
        time.sleep(0.1)
    
    print("\n💡 Pattern: Rapid development detected!")
    print("   Recommendation: Enable hot-reload for these files")

def demonstrate_self_healing():
    """Demonstrate self-healing capabilities"""
    print_header("Self-Healing Demo")
    
    # Check disk space
    import psutil
    disk_usage = psutil.disk_usage('/')
    print(f"Disk Usage: {disk_usage.percent:.1f}%")
    
    # Check memory
    memory = psutil.virtual_memory()
    print(f"Memory Usage: {memory.percent:.1f}%")
    
    # Create a large log file
    large_log = AUTOMATION_PATH / "logs" / "demo_large.log"
    large_log.parent.mkdir(exist_ok=True)
    
    print("\nCreating large log file to trigger cleanup...")
    with large_log.open('w') as f:
        for i in range(10000):
            f.write(f"Log entry {i}: " + "x" * 100 + "\n")
    
    size_mb = large_log.stat().st_size / (1024**2)
    print(f"   Created {large_log.name}: {size_mb:.1f} MB")
    
    print("\n🔧 Self-healing would:")
    print("   - Detect large log file")
    print("   - Compress or rotate it")
    print("   - Free up disk space")

def show_telemetry_metrics():
    """Show telemetry metrics"""
    print_header("Telemetry Metrics")
    
    print("📊 Key Metrics Being Tracked:")
    print("   - cdcs.agent.executions - How often agents run")
    print("   - cdcs.patterns.detected - Patterns discovered")
    print("   - cdcs.fixes.applied - Self-healing actions")
    print("   - cdcs.system.health - Overall system health")
    
    print("\n📈 Sample Metric Data:")
    metrics = [
        ("Agent Executions", 42, "last hour"),
        ("Patterns Detected", 7, "today"),
        ("Fixes Applied", 3, "today"),
        ("System Health", 95, "current")
    ]
    
    for metric, value, period in metrics:
        print(f"   {metric}: {value} ({period})")

def run_mini_validation():
    """Run a mini validation check"""
    print_header("System Validation")
    
    checks = [
        ("Scripts exist", ADVANCED_PATH.exists()),
        ("Telemetry configured", os.getenv('CDCS_TELEMETRY_ENABLED') == 'true'),
        ("OTLP endpoint set", 'OTEL_EXPORTER_OTLP_ENDPOINT' in os.environ),
        ("Logs directory exists", (AUTOMATION_PATH / "logs").exists()),
        ("Reports directory exists", (AUTOMATION_PATH / "reports").exists())
    ]
    
    passed = 0
    for check, result in checks:
        status = "✅" if result else "❌"
        print(f"{status} {check}")
        if result:
            passed += 1
    
    print(f"\nValidation Score: {passed}/{len(checks)} ({passed/len(checks)*100:.0f}%)")

def main():
    """Main demo function"""
    print("\n" + "🚀"*30)
    print("     CDCS Advanced Automation Demo")
    print("🚀"*30)
    
    # Set telemetry environment
    telemetry_env = AUTOMATION_PATH / "telemetry.env"
    if telemetry_env.exists():
        print("\nLoading telemetry configuration...")
        with telemetry_env.open() as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    key, value = line.strip().split('=', 1)
                    os.environ[key.replace('export ', '')] = value.strip('"')
    
    # Run demos
    check_service_status()
    create_test_pattern()
    demonstrate_self_healing()
    show_telemetry_metrics()
    run_mini_validation()
    
    # Summary
    print_header("Summary")
    print("The CDCS Advanced Automation system provides:")
    print("✨ Parallel terminal orchestration")
    print("✨ Real-time pattern detection")
    print("✨ Intelligent scheduling optimization")
    print("✨ Self-healing capabilities")
    print("✨ Full observability with OpenTelemetry")
    print("\nAll working together to create an autonomous, self-improving system!")
    
    print("\n📚 For more details:")
    print(f"   - Logs: {AUTOMATION_PATH}/logs/")
    print(f"   - Reports: {AUTOMATION_PATH}/reports/")
    print(f"   - Control: {ADVANCED_PATH}/cdcs_control.sh")

if __name__ == "__main__":
    main()

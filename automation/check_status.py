#!/usr/bin/env python3
"""
CDCS Automation Status Checker
Shows current status of all automation components
"""

import sqlite3
import json
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List
import subprocess

class StatusChecker:
    def __init__(self):
        self.base_path = Path("/Users/sac/claude-desktop-context")
        self.automation_path = self.base_path / "automation"
        self.db_path = self.automation_path / "cdcs_intelligence.db"
        
    def check_cron_status(self) -> Dict:
        """Check status of cron jobs"""
        try:
            result = subprocess.run(['crontab', '-l'], capture_output=True, text=True)
            cron_lines = result.stdout.splitlines()
            
            cdcs_jobs = [line for line in cron_lines if 'CDCS_' in line]
            
            return {
                'active': len(cdcs_jobs) > 0,
                'job_count': len(cdcs_jobs),
                'jobs': [line.split('#')[-1].strip() for line in cdcs_jobs]
            }
        except:
            return {'active': False, 'job_count': 0, 'jobs': []}
            
    def check_ollama_status(self) -> Dict:
        """Check if ollama is running"""
        try:
            result = subprocess.run(['ollama', 'list'], capture_output=True, text=True)
            return {
                'running': result.returncode == 0,
                'models': result.stdout.strip() if result.returncode == 0 else ""
            }
        except:
            return {'running': False, 'models': ""}
            
    def get_recent_runs(self) -> List[Dict]:
        """Get recent automation runs"""
        if not self.db_path.exists():
            return []
            
        conn = sqlite3.connect(self.db_path)
        runs = conn.execute("""
            SELECT timestamp, agent, task, patterns_found, evolution_score
            FROM automation_runs
            ORDER BY timestamp DESC
            LIMIT 10
        """).fetchall()
        conn.close()
        
        return [
            {
                'timestamp': r[0],
                'agent': r[1],
                'task': r[2],
                'patterns_found': r[3],
                'evolution_score': r[4]
            }
            for r in runs
        ]
        
    def get_system_metrics(self) -> Dict:
        """Get current system metrics"""
        if not self.db_path.exists():
            return {}
            
        conn = sqlite3.connect(self.db_path)
        metrics = conn.execute("""
            SELECT * FROM system_metrics
            ORDER BY timestamp DESC
            LIMIT 1
        """).fetchone()
        conn.close()
        
        if metrics:
            return {
                'timestamp': metrics[0],
                'context_efficiency': metrics[1],
                'pattern_hit_rate': metrics[2],
                'compression_ratio': metrics[3],
                'evolution_velocity': metrics[4],
                'knowledge_retention': metrics[5]
            }
        return {}
        
    def check_health_status(self) -> Dict:
        """Check current health status"""
        health_file = self.base_path / "health" / "current_health.json"
        
        if health_file.exists():
            data = json.loads(health_file.read_text())
            return data
        return {'overall_health': 'unknown', 'health_score': 0.0}
        
    def check_log_activity(self) -> Dict:
        """Check recent log activity"""
        log_path = self.automation_path / "logs"
        activity = {}
        
        if log_path.exists():
            for log_file in log_path.glob("*.log"):
                if log_file.stat().st_size > 0:
                    modified = datetime.fromtimestamp(log_file.stat().st_mtime)
                    activity[log_file.stem] = {
                        'last_modified': modified.isoformat(),
                        'size_kb': log_file.stat().st_size / 1024,
                        'active': (datetime.now() - modified) < timedelta(hours=24)
                    }
                    
        return activity
        
    def display_status(self):
        """Display comprehensive status"""
        print("=" * 60)
        print("CDCS 24/7 Automation Status")
        print("=" * 60)
        print()
        
        # Cron status
        cron_status = self.check_cron_status()
        print(f"🔄 Cron Jobs: {'✅ Active' if cron_status['active'] else '❌ Inactive'}")
        print(f"   Jobs configured: {cron_status['job_count']}")
        for job in cron_status['jobs']:
            print(f"   - {job}")
        print()
        
        # Ollama status
        ollama_status = self.check_ollama_status()
        print(f"🤖 Ollama: {'✅ Running' if ollama_status['running'] else '❌ Not running'}")
        if ollama_status['running']:
            print(f"   Models: {ollama_status['models']}")
        print()
        
        # System metrics
        metrics = self.get_system_metrics()
        if metrics:
            print("📊 System Metrics:")
            print(f"   Context efficiency: {metrics['context_efficiency']:.2%}")
            print(f"   Pattern hit rate: {metrics['pattern_hit_rate']:.2%}")
            print(f"   Compression ratio: {metrics['compression_ratio']:.1f}:1")
            print(f"   Evolution velocity: {metrics['evolution_velocity']:.3f}/day")
            print(f"   Knowledge retention: {metrics['knowledge_retention']:.2%}")
            print()
        
        # Health status
        health = self.check_health_status()
        health_emoji = {
            'healthy': '🟢',
            'warning': '🟡',
            'critical': '🔴',
            'unknown': '⚪'
        }
        print(f"💚 System Health: {health_emoji.get(health.get('overall_health', 'unknown'), '⚪')} {health.get('overall_health', 'unknown').upper()}")
        print(f"   Health score: {health.get('health_score', 0.0):.2f}")
        print()
        
        # Recent runs
        recent_runs = self.get_recent_runs()
        if recent_runs:
            print("🏃 Recent Automation Runs:")
            for run in recent_runs[:5]:
                timestamp = datetime.fromisoformat(run['timestamp'])
                time_ago = datetime.now() - timestamp
                hours_ago = time_ago.total_seconds() / 3600
                
                print(f"   {run['agent']}: {hours_ago:.1f}h ago")
                if run['patterns_found']:
                    print(f"     - Patterns found: {run['patterns_found']}")
                if run['evolution_score']:
                    print(f"     - Evolution score: {run['evolution_score']:.2f}")
            print()
        
        # Log activity
        log_activity = self.check_log_activity()
        if log_activity:
            print("📝 Log Activity:")
            for log_name, info in log_activity.items():
                status = "✅" if info['active'] else "💤"
                print(f"   {status} {log_name}: {info['size_kb']:.1f}KB")
            print()
        
        print("=" * 60)
        print("To view live logs: tail -f /Users/sac/claude-desktop-context/automation/logs/*.log")
        print("To stop automation: /Users/sac/claude-desktop-context/automation/disable_cron.sh")
        print("=" * 60)

if __name__ == "__main__":
    checker = StatusChecker()
    checker.display_status()

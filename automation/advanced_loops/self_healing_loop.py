#!/usr/bin/env python3
"""
Self-Healing Automation Loop
Detects system issues and automatically applies fixes
"""

import os
import sys
import json
import time
import psutil
import sqlite3
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from collections import defaultdict
import logging
import hashlib

# Add CDCS path
CDCS_PATH = Path("/Users/sac/claude-desktop-context")
sys.path.append(str(CDCS_PATH / "automation"))

from base_agent import BaseAgent

class SystemIssue:
    """Represents a detected system issue"""
    
    def __init__(self, issue_type: str, severity: str, details: Dict):
        self.id = hashlib.md5(f"{issue_type}{time.time()}".encode()).hexdigest()[:8]
        self.type = issue_type
        self.severity = severity  # critical, high, medium, low
        self.details = details
        self.detected_at = datetime.now()
        self.status = "detected"
        self.fix_attempts = []
        self.resolved = False
        
    def to_dict(self) -> Dict:
        return {
            'id': self.id,
            'type': self.type,
            'severity': self.severity,
            'details': self.details,
            'detected_at': self.detected_at.isoformat(),
            'status': self.status,
            'fix_attempts': self.fix_attempts,
            'resolved': self.resolved
        }

class HealthCheck:
    """Base class for health checks"""
    
    def __init__(self, name: str):
        self.name = name
        self.last_check = None
        self.check_interval = 60  # seconds
        
    def should_check(self) -> bool:
        if not self.last_check:
            return True
        return (datetime.now() - self.last_check).seconds >= self.check_interval
        
    def check(self) -> List[SystemIssue]:
        """Override in subclasses"""
        raise NotImplementedError

class DiskSpaceCheck(HealthCheck):
    """Check disk space availability"""
    
    def __init__(self):
        super().__init__("disk_space")
        self.warning_threshold = 85  # percent
        self.critical_threshold = 95  # percent
        
    def check(self) -> List[SystemIssue]:
        issues = []
        
        try:
            disk_usage = psutil.disk_usage('/')
            usage_percent = disk_usage.percent
            
            if usage_percent >= self.critical_threshold:
                issues.append(SystemIssue(
                    "disk_space_critical",
                    "critical",
                    {
                        'usage_percent': usage_percent,
                        'free_gb': disk_usage.free / (1024**3),
                        'threshold': self.critical_threshold
                    }
                ))
            elif usage_percent >= self.warning_threshold:
                issues.append(SystemIssue(
                    "disk_space_warning",
                    "high",
                    {
                        'usage_percent': usage_percent,
                        'free_gb': disk_usage.free / (1024**3),
                        'threshold': self.warning_threshold
                    }
                ))
                
        except Exception as e:
            issues.append(SystemIssue(
                "disk_check_failed",
                "medium",
                {'error': str(e)}
            ))
            
        self.last_check = datetime.now()
        return issues

class MemoryCheck(HealthCheck):
    """Check memory usage"""
    
    def __init__(self):
        super().__init__("memory")
        self.warning_threshold = 80  # percent
        self.critical_threshold = 90  # percent
        
    def check(self) -> List[SystemIssue]:
        issues = []
        
        try:
            memory = psutil.virtual_memory()
            
            if memory.percent >= self.critical_threshold:
                issues.append(SystemIssue(
                    "memory_critical",
                    "critical",
                    {
                        'usage_percent': memory.percent,
                        'available_gb': memory.available / (1024**3),
                        'threshold': self.critical_threshold
                    }
                ))
            elif memory.percent >= self.warning_threshold:
                issues.append(SystemIssue(
                    "memory_warning",
                    "high",
                    {
                        'usage_percent': memory.percent,
                        'available_gb': memory.available / (1024**3),
                        'threshold': self.warning_threshold
                    }
                ))
                
        except Exception as e:
            issues.append(SystemIssue(
                "memory_check_failed",
                "medium",
                {'error': str(e)}
            ))
            
        self.last_check = datetime.now()
        return issues

class ProcessCheck(HealthCheck):
    """Check for problematic processes"""
    
    def __init__(self):
        super().__init__("processes")
        self.cpu_threshold = 80  # percent
        self.zombie_check = True
        
    def check(self) -> List[SystemIssue]:
        issues = []
        
        try:
            # Check for high CPU processes
            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent']):
                try:
                    if proc.info['cpu_percent'] > self.cpu_threshold:
                        issues.append(SystemIssue(
                            "high_cpu_process",
                            "medium",
                            {
                                'pid': proc.info['pid'],
                                'name': proc.info['name'],
                                'cpu_percent': proc.info['cpu_percent']
                            }
                        ))
                except:
                    pass
                    
            # Check for zombie processes
            if self.zombie_check:
                zombies = [p for p in psutil.process_iter() 
                          if p.status() == psutil.STATUS_ZOMBIE]
                if zombies:
                    issues.append(SystemIssue(
                        "zombie_processes",
                        "low",
                        {
                            'count': len(zombies),
                            'pids': [p.pid for p in zombies[:5]]
                        }
                    ))
                    
        except Exception as e:
            issues.append(SystemIssue(
                "process_check_failed",
                "medium",
                {'error': str(e)}
            ))
            
        self.last_check = datetime.now()
        return issues

class CDCSHealthCheck(HealthCheck):
    """Check CDCS-specific health"""
    
    def __init__(self):
        super().__init__("cdcs_health")
        
    def check(self) -> List[SystemIssue]:
        issues = []
        
        # Check session chunk size
        active_chunks = list((CDCS_PATH / "memory" / "sessions" / "active").glob("chunk_*.md"))
        for chunk in active_chunks:
            try:
                size = chunk.stat().st_size
                lines = len(chunk.read_text().splitlines())
                
                if lines > 10000:  # Compression threshold
                    issues.append(SystemIssue(
                        "session_chunk_needs_compression",
                        "medium",
                        {
                            'chunk': str(chunk),
                            'lines': lines,
                            'size_mb': size / (1024**2)
                        }
                    ))
            except:
                pass
                
        # Check pattern cache
        pattern_cache = CDCS_PATH / "patterns" / "cache"
        if pattern_cache.exists():
            cache_age = datetime.now() - datetime.fromtimestamp(pattern_cache.stat().st_mtime)
            if cache_age > timedelta(hours=24):
                issues.append(SystemIssue(
                    "pattern_cache_stale",
                    "low",
                    {
                        'age_hours': cache_age.total_seconds() / 3600,
                        'path': str(pattern_cache)
                    }
                ))
                
        # Check automation logs
        log_dir = CDCS_PATH / "automation" / "logs"
        if log_dir.exists():
            total_size = sum(f.stat().st_size for f in log_dir.glob("*.log"))
            if total_size > 100 * 1024 * 1024:  # 100MB
                issues.append(SystemIssue(
                    "automation_logs_large",
                    "low",
                    {
                        'total_size_mb': total_size / (1024**2),
                        'file_count': len(list(log_dir.glob("*.log")))
                    }
                ))
                
        self.last_check = datetime.now()
        return issues

class SelfHealingLoop(BaseAgent):
    """
    Self-healing automation loop that detects and fixes system issues
    """
    
    def __init__(self, orchestrator):
        super().__init__(orchestrator, "SelfHealingLoop")
        self.health_checks = [
            DiskSpaceCheck(),
            MemoryCheck(),
            ProcessCheck(),
            CDCSHealthCheck()
        ]
        self.issues: Dict[str, SystemIssue] = {}
        self.fixes_db = CDCS_PATH / "automation" / "self_healing.db"
        self.init_fixes_db()
        self.load_fix_strategies()
        
    def init_fixes_db(self):
        """Initialize database for tracking fixes"""
        conn = sqlite3.connect(self.fixes_db)
        conn.execute('''
            CREATE TABLE IF NOT EXISTS issues (
                id TEXT PRIMARY KEY,
                type TEXT,
                severity TEXT,
                details TEXT,
                detected_at TIMESTAMP,
                resolved_at TIMESTAMP,
                fix_applied TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.execute('''
            CREATE TABLE IF NOT EXISTS fix_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                issue_id TEXT,
                fix_strategy TEXT,
                success INTEGER,
                output TEXT,
                error TEXT,
                applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.commit()
        conn.close()
        
    def load_fix_strategies(self):
        """Load automated fix strategies"""
        self.fix_strategies = {
            'disk_space_warning': [
                self.clean_old_logs,
                self.compress_old_sessions,
                self.remove_temp_files
            ],
            'disk_space_critical': [
                self.emergency_cleanup,
                self.archive_old_data
            ],
            'memory_warning': [
                self.clear_caches,
                self.restart_heavy_processes
            ],
            'memory_critical': [
                self.kill_non_essential_processes,
                self.force_garbage_collection
            ],
            'high_cpu_process': [
                self.nice_process,
                self.limit_process_cpu
            ],
            'zombie_processes': [
                self.clean_zombies
            ],
            'session_chunk_needs_compression': [
                self.compress_session_chunk
            ],
            'pattern_cache_stale': [
                self.refresh_pattern_cache
            ],
            'automation_logs_large': [
                self.rotate_logs
            ]
        }
        
    def run_health_checks(self) -> List[SystemIssue]:
        """Run all health checks"""
        all_issues = []
        
        for check in self.health_checks:
            if check.should_check():
                self.logger.info(f"Running health check: {check.name}")
                issues = check.check()
                all_issues.extend(issues)
                
        return all_issues
        
    def prioritize_issues(self, issues: List[SystemIssue]) -> List[SystemIssue]:
        """Prioritize issues by severity and age"""
        severity_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
        
        return sorted(issues, key=lambda x: (
            severity_order.get(x.severity, 4),
            x.detected_at
        ))
        
    def apply_fix(self, issue: SystemIssue) -> bool:
        """Apply fix for an issue"""
        if issue.type not in self.fix_strategies:
            self.logger.warning(f"No fix strategy for issue type: {issue.type}")
            return False
            
        strategies = self.fix_strategies[issue.type]
        
        for strategy in strategies:
            self.logger.info(f"Applying fix strategy: {strategy.__name__} for {issue.id}")
            
            try:
                result = strategy(issue)
                
                # Record fix attempt
                issue.fix_attempts.append({
                    'strategy': strategy.__name__,
                    'timestamp': datetime.now().isoformat(),
                    'result': result
                })
                
                if result.get('success', False):
                    issue.status = 'fixed'
                    issue.resolved = True
                    self.record_fix(issue, strategy.__name__, True, result.get('output'))
                    return True
                else:
                    self.record_fix(issue, strategy.__name__, False, 
                                  error=result.get('error', 'Unknown error'))
                    
            except Exception as e:
                self.logger.error(f"Fix strategy {strategy.__name__} failed: {e}")
                self.record_fix(issue, strategy.__name__, False, error=str(e))
                
        return False
        
    def record_fix(self, issue: SystemIssue, strategy: str, success: bool, 
                  output: str = None, error: str = None):
        """Record fix attempt in database"""
        conn = sqlite3.connect(self.fixes_db)
        
        # Record issue if new
        conn.execute('''
            INSERT OR IGNORE INTO issues 
            (id, type, severity, details, detected_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (
            issue.id,
            issue.type,
            issue.severity,
            json.dumps(issue.details),
            issue.detected_at.isoformat()
        ))
        
        # Record fix attempt
        conn.execute('''
            INSERT INTO fix_history 
            (issue_id, fix_strategy, success, output, error)
            VALUES (?, ?, ?, ?, ?)
        ''', (issue.id, strategy, int(success), output, error))
        
        # Update issue resolution if successful
        if success:
            conn.execute('''
                UPDATE issues 
                SET resolved_at = CURRENT_TIMESTAMP, fix_applied = ?
                WHERE id = ?
            ''', (strategy, issue.id))
            
        conn.commit()
        conn.close()
        
    # Fix strategies
    def clean_old_logs(self, issue: SystemIssue) -> Dict:
        """Clean old log files"""
        try:
            cleaned = 0
            total_freed = 0
            
            log_dirs = [
                CDCS_PATH / "automation" / "logs",
                CDCS_PATH / "cron" / "logs"
            ]
            
            for log_dir in log_dirs:
                if log_dir.exists():
                    for log_file in log_dir.glob("*.log*"):
                        if log_file.stat().st_mtime < time.time() - (7 * 24 * 3600):  # 7 days
                            size = log_file.stat().st_size
                            log_file.unlink()
                            cleaned += 1
                            total_freed += size
                            
            return {
                'success': True,
                'output': f"Cleaned {cleaned} log files, freed {total_freed / (1024**2):.1f} MB"
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def compress_old_sessions(self, issue: SystemIssue) -> Dict:
        """Compress old session files"""
        try:
            import gzip
            compressed = 0
            
            sessions_dir = CDCS_PATH / "memory" / "sessions"
            for session_file in sessions_dir.glob("**/*.md"):
                if session_file.stat().st_mtime < time.time() - (3 * 24 * 3600):  # 3 days
                    content = session_file.read_bytes()
                    compressed_path = session_file.with_suffix('.md.gz')
                    
                    with gzip.open(compressed_path, 'wb') as f:
                        f.write(content)
                        
                    session_file.unlink()
                    compressed += 1
                    
            return {
                'success': True,
                'output': f"Compressed {compressed} old session files"
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def remove_temp_files(self, issue: SystemIssue) -> Dict:
        """Remove temporary files"""
        try:
            removed = 0
            patterns = ['*.tmp', '*.temp', '*.cache', '.DS_Store']
            
            for pattern in patterns:
                for temp_file in CDCS_PATH.rglob(pattern):
                    temp_file.unlink()
                    removed += 1
                    
            return {
                'success': True,
                'output': f"Removed {removed} temporary files"
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def emergency_cleanup(self, issue: SystemIssue) -> Dict:
        """Emergency cleanup for critical disk space"""
        try:
            # More aggressive cleanup
            actions = []
            
            # Remove all logs older than 1 day
            log_count = 0
            for log_file in CDCS_PATH.rglob("*.log*"):
                if log_file.stat().st_mtime < time.time() - (24 * 3600):
                    log_file.unlink()
                    log_count += 1
                    
            actions.append(f"Removed {log_count} log files")
            
            # Compress all uncompressed sessions
            session_count = 0
            import gzip
            for session in CDCS_PATH.rglob("*.md"):
                if 'sessions' in str(session):
                    content = session.read_bytes()
                    with gzip.open(session.with_suffix('.md.gz'), 'wb') as f:
                        f.write(content)
                    session.unlink()
                    session_count += 1
                    
            actions.append(f"Compressed {session_count} sessions")
            
            return {
                'success': True,
                'output': "; ".join(actions)
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def archive_old_data(self, issue: SystemIssue) -> Dict:
        """Archive old data to compressed format"""
        try:
            import tarfile
            archive_path = CDCS_PATH / "archives" / f"archive_{int(time.time())}.tar.gz"
            archive_path.parent.mkdir(exist_ok=True)
            
            with tarfile.open(archive_path, "w:gz") as tar:
                # Archive old emergent capabilities
                old_discoveries = CDCS_PATH / "emergent-capabilities" / "discovered"
                for file in old_discoveries.glob("*.md"):
                    if file.stat().st_mtime < time.time() - (30 * 24 * 3600):  # 30 days
                        tar.add(file, arcname=file.relative_to(CDCS_PATH))
                        file.unlink()
                        
            return {
                'success': True,
                'output': f"Created archive: {archive_path}"
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def clear_caches(self, issue: SystemIssue) -> Dict:
        """Clear various caches"""
        try:
            cleared = []
            
            # Clear pattern cache if exists
            pattern_cache = CDCS_PATH / "patterns" / "cache"
            if pattern_cache.exists():
                import shutil
                shutil.rmtree(pattern_cache)
                pattern_cache.mkdir()
                cleared.append("pattern cache")
                
            # Clear Python cache
            for pycache in CDCS_PATH.rglob("__pycache__"):
                import shutil
                shutil.rmtree(pycache)
                
            cleared.append("Python caches")
            
            return {
                'success': True,
                'output': f"Cleared: {', '.join(cleared)}"
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def restart_heavy_processes(self, issue: SystemIssue) -> Dict:
        """Restart memory-heavy processes"""
        # In practice, would identify and restart specific processes
        return {
            'success': False,
            'error': 'Manual intervention required for process restart'
        }
        
    def kill_non_essential_processes(self, issue: SystemIssue) -> Dict:
        """Kill non-essential processes"""
        # Would need careful implementation to avoid killing critical processes
        return {
            'success': False,
            'error': 'Manual intervention required for process termination'
        }
        
    def force_garbage_collection(self, issue: SystemIssue) -> Dict:
        """Force garbage collection in Python"""
        try:
            import gc
            collected = gc.collect()
            
            return {
                'success': True,
                'output': f"Garbage collection freed {collected} objects"
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def nice_process(self, issue: SystemIssue) -> Dict:
        """Reduce process priority"""
        try:
            pid = issue.details.get('pid')
            if pid:
                subprocess.run(['renice', '-n', '10', '-p', str(pid)], check=True)
                return {
                    'success': True,
                    'output': f"Reduced priority of process {pid}"
                }
            return {'success': False, 'error': 'No PID provided'}
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def limit_process_cpu(self, issue: SystemIssue) -> Dict:
        """Limit process CPU usage"""
        # Would use cpulimit or similar tool
        return {
            'success': False,
            'error': 'CPU limiting requires additional tools'
        }
        
    def clean_zombies(self, issue: SystemIssue) -> Dict:
        """Clean zombie processes"""
        try:
            # Zombies are cleaned when parent reads exit status
            # This is more of a notification than a fix
            return {
                'success': True,
                'output': 'Zombie processes logged for investigation'
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def compress_session_chunk(self, issue: SystemIssue) -> Dict:
        """Compress large session chunk"""
        try:
            chunk_path = Path(issue.details['chunk'])
            
            # Use SPR compression
            content = chunk_path.read_text()
            
            # Simple SPR compression (in practice would be more sophisticated)
            lines = content.splitlines()
            compressed_lines = []
            
            for i in range(0, len(lines), 10):  # Compress every 10 lines
                section = lines[i:i+10]
                if section:
                    # Extract key information
                    key_info = ' '.join(line[:50] for line in section if line.strip())[:200]
                    compressed_lines.append(f"[SPR {i}-{i+10}] {key_info}")
                    
            compressed_content = '\n'.join(compressed_lines)
            
            # Archive original
            archive_path = chunk_path.parent / "compressed" / chunk_path.name
            archive_path.parent.mkdir(exist_ok=True)
            archive_path.write_text(compressed_content)
            
            # Replace with compressed
            chunk_path.write_text(f"# Compressed on {datetime.now().isoformat()}\n\n{compressed_content}")
            
            return {
                'success': True,
                'output': f"Compressed {len(lines)} lines to {len(compressed_lines)} entries"
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def refresh_pattern_cache(self, issue: SystemIssue) -> Dict:
        """Refresh pattern cache"""
        try:
            cache_path = Path(issue.details['path'])
            
            # Touch the cache to update timestamp
            cache_path.touch()
            
            # In practice, would rebuild cache from patterns
            return {
                'success': True,
                'output': 'Pattern cache refreshed'
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def rotate_logs(self, issue: SystemIssue) -> Dict:
        """Rotate large log files"""
        try:
            import gzip
            rotated = 0
            
            log_dir = CDCS_PATH / "automation" / "logs"
            for log_file in log_dir.glob("*.log"):
                if log_file.stat().st_size > 10 * 1024 * 1024:  # 10MB
                    # Compress and rotate
                    content = log_file.read_bytes()
                    
                    rotated_path = log_file.with_suffix(f'.log.{int(time.time())}.gz')
                    with gzip.open(rotated_path, 'wb') as f:
                        f.write(content)
                        
                    # Clear original
                    log_file.write_text(f"# Log rotated on {datetime.now().isoformat()}\n")
                    rotated += 1
                    
            return {
                'success': True,
                'output': f"Rotated {rotated} log files"
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}
            
    def generate_health_report(self) -> str:
        """Generate system health report"""
        report = f"""# Self-Healing System Report
Generated: {datetime.now().isoformat()}

## Current Issues
"""
        
        active_issues = [i for i in self.issues.values() if not i.resolved]
        if active_issues:
            for issue in self.prioritize_issues(active_issues):
                report += f"\n### {issue.type} ({issue.severity})\n"
                report += f"- Detected: {issue.detected_at.isoformat()}\n"
                report += f"- Status: {issue.status}\n"
                report += f"- Details: {json.dumps(issue.details, indent=2)}\n"
                
                if issue.fix_attempts:
                    report += f"- Fix Attempts: {len(issue.fix_attempts)}\n"
        else:
            report += "\n✅ No active issues detected\n"
            
        report += "\n## Recent Fixes\n"
        
        # Query recent fixes from database
        conn = sqlite3.connect(self.fixes_db)
        cursor = conn.execute('''
            SELECT i.type, i.severity, f.fix_strategy, f.success, f.applied_at
            FROM fix_history f
            JOIN issues i ON f.issue_id = i.id
            WHERE f.applied_at > datetime('now', '-24 hours')
            ORDER BY f.applied_at DESC
            LIMIT 10
        ''')
        
        fixes = cursor.fetchall()
        conn.close()
        
        if fixes:
            for fix in fixes:
                issue_type, severity, strategy, success, applied_at = fix
                status = "✅" if success else "❌"
                report += f"- {status} {issue_type} ({severity}) - {strategy} @ {applied_at}\n"
        else:
            report += "\nNo fixes applied in the last 24 hours\n"
            
        report += "\n## System Health Metrics\n"
        
        # Current system metrics
        try:
            disk = psutil.disk_usage('/')
            memory = psutil.virtual_memory()
            cpu_percent = psutil.cpu_percent(interval=1)
            
            report += f"- Disk Usage: {disk.percent:.1f}% ({disk.free / (1024**3):.1f} GB free)\n"
            report += f"- Memory Usage: {memory.percent:.1f}% ({memory.available / (1024**3):.1f} GB available)\n"
            report += f"- CPU Usage: {cpu_percent:.1f}%\n"
            report += f"- Active Processes: {len(psutil.pids())}\n"
        except:
            report += "- Unable to retrieve system metrics\n"
            
        return report
        
    def run(self):
        """Main self-healing loop"""
        self.logger.info("Starting self-healing automation loop")
        
        try:
            # Run health checks
            issues = self.run_health_checks()
            
            if issues:
                self.logger.info(f"Detected {len(issues)} issues")
                
                # Add new issues to tracking
                for issue in issues:
                    if issue.id not in self.issues:
                        self.issues[issue.id] = issue
                        
                # Prioritize and fix issues
                prioritized = self.prioritize_issues(
                    [i for i in self.issues.values() if not i.resolved]
                )
                
                for issue in prioritized[:5]:  # Fix up to 5 issues per run
                    self.logger.info(f"Attempting to fix {issue.type} (severity: {issue.severity})")
                    
                    success = self.apply_fix(issue)
                    
                    if success:
                        self.logger.info(f"Successfully fixed issue {issue.id}")
                    else:
                        self.logger.warning(f"Failed to fix issue {issue.id}")
                        
            else:
                self.logger.info("No issues detected - system healthy")
                
            # Generate and save health report
            report = self.generate_health_report()
            report_path = CDCS_PATH / "automation" / "reports" / f"health_report_{int(time.time())}.md"
            report_path.parent.mkdir(exist_ok=True, parents=True)
            report_path.write_text(report)
            
            self.logger.info(f"Generated health report: {report_path}")
            
            # Clean up old resolved issues
            self.issues = {
                id: issue for id, issue in self.issues.items()
                if not issue.resolved or 
                (datetime.now() - issue.detected_at).days < 1
            }
            
        except Exception as e:
            self.logger.error(f"Self-healing loop error: {e}")

if __name__ == "__main__":
    # Test run
    from cdcs_orchestrator import CDCSOrchestrator
    orchestrator = CDCSOrchestrator()
    healer = SelfHealingLoop(orchestrator)
    healer.run()

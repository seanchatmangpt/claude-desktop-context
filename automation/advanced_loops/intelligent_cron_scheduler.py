#!/usr/bin/env python3
"""
Intelligent Cron Scheduler - Adaptive Automation Timing
Learns optimal execution times and adjusts cron schedules dynamically
"""

import os
import sys
import json
import sqlite3
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from collections import defaultdict
import statistics
import logging

# Add CDCS path
CDCS_PATH = Path("/Users/sac/claude-desktop-context")
sys.path.append(str(CDCS_PATH / "automation"))

from base_agent import BaseAgent

class CronJob:
    """Represents an intelligent cron job with adaptive scheduling"""
    
    def __init__(self, name: str, command: str, initial_schedule: str):
        self.name = name
        self.command = command
        self.current_schedule = initial_schedule
        self.initial_schedule = initial_schedule
        self.execution_history = []
        self.performance_metrics = {
            'avg_duration': 0,
            'success_rate': 1.0,
            'resource_usage': {},
            'optimal_times': []
        }
        self.last_adjustment = datetime.now()
        
    def record_execution(self, start_time: datetime, end_time: datetime, 
                        success: bool, metrics: Dict):
        """Record job execution for learning"""
        execution = {
            'start': start_time,
            'end': end_time,
            'duration': (end_time - start_time).total_seconds(),
            'success': success,
            'metrics': metrics,
            'hour': start_time.hour,
            'day_of_week': start_time.weekday(),
            'system_load': metrics.get('system_load', 0)
        }
        
        self.execution_history.append(execution)
        self.update_performance_metrics()
        
    def update_performance_metrics(self):
        """Update performance metrics based on history"""
        if not self.execution_history:
            return
            
        # Calculate average duration
        durations = [e['duration'] for e in self.execution_history[-100:]]
        self.performance_metrics['avg_duration'] = statistics.mean(durations)
        
        # Calculate success rate
        recent = self.execution_history[-50:]
        successes = sum(1 for e in recent if e['success'])
        self.performance_metrics['success_rate'] = successes / len(recent)
        
        # Find optimal execution times (low load, high success)
        time_performance = defaultdict(list)
        for e in self.execution_history:
            if e['success']:
                score = 1.0 / (1.0 + e['system_load'])
                time_performance[e['hour']].append(score)
        
        optimal_hours = []
        for hour, scores in time_performance.items():
            if len(scores) >= 3:  # Need enough data
                avg_score = statistics.mean(scores)
                optimal_hours.append((hour, avg_score))
        
        optimal_hours.sort(key=lambda x: x[1], reverse=True)
        self.performance_metrics['optimal_times'] = [h[0] for h in optimal_hours[:3]]
    
    def suggest_schedule_adjustment(self) -> Optional[str]:
        """Suggest schedule adjustment based on performance"""
        if len(self.execution_history) < 10:
            return None  # Not enough data
            
        # Don't adjust too frequently
        if (datetime.now() - self.last_adjustment).days < 7:
            return None
            
        optimal_times = self.performance_metrics['optimal_times']
        if not optimal_times:
            return None
            
        # Parse current schedule (simplified cron parsing)
        parts = self.current_schedule.split()
        if len(parts) != 5:
            return None
            
        current_hour = parts[1]
        
        # If current hour is not in optimal times, suggest change
        if current_hour != '*' and int(current_hour) not in optimal_times:
            suggested_hour = optimal_times[0]
            parts[1] = str(suggested_hour)
            return ' '.join(parts)
            
        return None

class IntelligentCronScheduler(BaseAgent):
    """
    Intelligent cron scheduler that learns optimal execution times
    and adapts schedules based on system performance
    """
    
    def __init__(self, orchestrator):
        super().__init__(orchestrator, "IntelligentCronScheduler")
        self.jobs: Dict[str, CronJob] = {}
        self.metrics_db = CDCS_PATH / "automation" / "cron_metrics.db"
        self.init_metrics_db()
        self.load_existing_jobs()
        
    def init_metrics_db(self):
        """Initialize metrics database"""
        conn = sqlite3.connect(self.metrics_db)
        conn.execute('''
            CREATE TABLE IF NOT EXISTS job_executions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                job_name TEXT,
                start_time TIMESTAMP,
                end_time TIMESTAMP,
                duration REAL,
                success INTEGER,
                system_load REAL,
                memory_usage REAL,
                error_message TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.execute('''
            CREATE TABLE IF NOT EXISTS schedule_adjustments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                job_name TEXT,
                old_schedule TEXT,
                new_schedule TEXT,
                reason TEXT,
                performance_gain REAL,
                adjusted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def load_existing_jobs(self):
        """Load existing cron jobs from various sources"""
        # Load from CDCS crontab
        crontab_path = CDCS_PATH / "cron" / "cdcs.crontab"
        if crontab_path.exists():
            self.parse_crontab(crontab_path)
        
        # Load from automation setup
        self.load_automation_jobs()
        
        # Load execution history from database
        self.load_execution_history()
    
    def parse_crontab(self, crontab_path: Path):
        """Parse crontab file and create job objects"""
        content = crontab_path.read_text()
        
        for line in content.split('\n'):
            line = line.strip()
            if line and not line.startswith('#'):
                # Simple cron line parsing
                parts = line.split(None, 5)
                if len(parts) == 6:
                    schedule = ' '.join(parts[:5])
                    command = parts[5]
                    
                    # Extract job name from command
                    job_name = self.extract_job_name(command)
                    
                    if job_name not in self.jobs:
                        self.jobs[job_name] = CronJob(job_name, command, schedule)
    
    def extract_job_name(self, command: str) -> str:
        """Extract job name from command"""
        # Try to find script name
        if '/' in command:
            script = command.split('/')[-1].split()[0]
            return script.replace('.sh', '').replace('.py', '')
        return command.split()[0]
    
    def load_automation_jobs(self):
        """Load Python automation agent jobs"""
        automation_jobs = [
            ("CDCS_ORCHESTRATOR", "0 * * * *", "cdcs_orchestrator.py"),
            ("CDCS_PATTERN_MINER", "0 */4 * * *", "pattern_miner.py"),
            ("CDCS_MEMORY_OPTIMIZER", "0 2 * * *", "memory_optimizer.py"),
            ("CDCS_KNOWLEDGE_SYNTHESIZER", "0 3 * * 0", "knowledge_synthesizer.py"),
            ("CDCS_EVOLUTION_HUNTER", "0 */6 * * *", "evolution_hunter.py"),
            ("CDCS_PREDICTIVE_LOADER", "*/30 8-18 * * 1-5", "predictive_loader.py"),
            ("CDCS_HEALTH_MONITOR", "0 */2 * * *", "system_health_monitor.py")
        ]
        
        for name, schedule, script in automation_jobs:
            if name not in self.jobs:
                command = f"python3 {CDCS_PATH}/automation/{script}"
                self.jobs[name] = CronJob(name, command, schedule)
    
    def load_execution_history(self):
        """Load execution history from database"""
        conn = sqlite3.connect(self.metrics_db)
        cursor = conn.execute('''
            SELECT job_name, start_time, end_time, success, system_load
            FROM job_executions
            ORDER BY start_time DESC
            LIMIT 1000
        ''')
        
        for row in cursor:
            job_name, start_str, end_str, success, system_load = row
            
            if job_name in self.jobs:
                start = datetime.fromisoformat(start_str)
                end = datetime.fromisoformat(end_str)
                metrics = {'system_load': system_load}
                
                self.jobs[job_name].record_execution(start, end, bool(success), metrics)
        
        conn.close()
    
    def monitor_job_execution(self, job: CronJob) -> Dict:
        """Monitor a job execution and collect metrics"""
        start_time = datetime.now()
        
        # Get system metrics before execution
        pre_metrics = self.get_system_metrics()
        
        # Execute job (simplified - in practice would monitor actual execution)
        success = True
        error_message = None
        
        try:
            # Simulate execution
            import random
            import time
            time.sleep(random.uniform(0.1, 0.5))  # Simulate work
            
            # Random failure for testing
            if random.random() < 0.1:  # 10% failure rate
                raise Exception("Simulated failure")
                
        except Exception as e:
            success = False
            error_message = str(e)
        
        end_time = datetime.now()
        
        # Get system metrics after execution
        post_metrics = self.get_system_metrics()
        
        # Calculate resource usage
        metrics = {
            'system_load': post_metrics['load_avg'],
            'memory_delta': post_metrics['memory_used'] - pre_metrics['memory_used'],
            'duration': (end_time - start_time).total_seconds()
        }
        
        # Record execution
        job.record_execution(start_time, end_time, success, metrics)
        self.save_execution_metrics(job.name, start_time, end_time, success, 
                                   metrics, error_message)
        
        return {
            'job': job.name,
            'success': success,
            'duration': metrics['duration'],
            'metrics': metrics
        }
    
    def get_system_metrics(self) -> Dict:
        """Get current system metrics"""
        metrics = {}
        
        # Load average
        try:
            load_avg = os.getloadavg()[0]  # 1-minute load average
            metrics['load_avg'] = load_avg
        except:
            metrics['load_avg'] = 0
        
        # Memory usage (simplified)
        try:
            import psutil
            memory = psutil.virtual_memory()
            metrics['memory_used'] = memory.percent
        except:
            metrics['memory_used'] = 50  # Default
            
        return metrics
    
    def save_execution_metrics(self, job_name: str, start: datetime, end: datetime,
                              success: bool, metrics: Dict, error: Optional[str]):
        """Save execution metrics to database"""
        conn = sqlite3.connect(self.metrics_db)
        conn.execute('''
            INSERT INTO job_executions 
            (job_name, start_time, end_time, duration, success, system_load, memory_usage, error_message)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            job_name,
            start.isoformat(),
            end.isoformat(),
            metrics['duration'],
            int(success),
            metrics['system_load'],
            metrics.get('memory_delta', 0),
            error
        ))
        conn.commit()
        conn.close()
    
    def analyze_performance_trends(self) -> Dict:
        """Analyze performance trends across all jobs"""
        trends = {
            'overall_health': 'good',
            'problem_jobs': [],
            'optimization_opportunities': [],
            'system_patterns': {}
        }
        
        # Analyze each job
        for job_name, job in self.jobs.items():
            if job.performance_metrics['success_rate'] < 0.8:
                trends['problem_jobs'].append({
                    'name': job_name,
                    'success_rate': job.performance_metrics['success_rate'],
                    'suggestion': 'Investigate failures'
                })
            
            # Check for optimization opportunities
            suggested_schedule = job.suggest_schedule_adjustment()
            if suggested_schedule:
                trends['optimization_opportunities'].append({
                    'job': job_name,
                    'current_schedule': job.current_schedule,
                    'suggested_schedule': suggested_schedule,
                    'reason': 'Better performance at suggested time'
                })
        
        # Analyze system-wide patterns
        all_executions = []
        for job in self.jobs.values():
            all_executions.extend(job.execution_history)
        
        if all_executions:
            # Find peak hours
            hour_loads = defaultdict(list)
            for e in all_executions:
                hour_loads[e['hour']].append(e['system_load'])
            
            peak_hours = []
            for hour, loads in hour_loads.items():
                if loads:
                    avg_load = statistics.mean(loads)
                    if avg_load > 0.7:  # High load threshold
                        peak_hours.append(hour)
            
            trends['system_patterns']['peak_hours'] = peak_hours
            trends['system_patterns']['recommended_quiet_hours'] = [
                h for h in range(24) if h not in peak_hours
            ]
        
        # Determine overall health
        if trends['problem_jobs']:
            trends['overall_health'] = 'needs_attention'
        elif trends['optimization_opportunities']:
            trends['overall_health'] = 'can_be_optimized'
            
        return trends
    
    def apply_schedule_optimization(self, job_name: str, new_schedule: str) -> bool:
        """Apply schedule optimization to a job"""
        if job_name not in self.jobs:
            return False
            
        job = self.jobs[job_name]
        old_schedule = job.current_schedule
        
        # Update cron (simplified - would actually modify crontab)
        success = self.update_crontab(job_name, new_schedule)
        
        if success:
            job.current_schedule = new_schedule
            job.last_adjustment = datetime.now()
            
            # Record adjustment
            conn = sqlite3.connect(self.metrics_db)
            conn.execute('''
                INSERT INTO schedule_adjustments 
                (job_name, old_schedule, new_schedule, reason)
                VALUES (?, ?, ?, ?)
            ''', (job_name, old_schedule, new_schedule, "Performance optimization"))
            conn.commit()
            conn.close()
            
            self.logger.info(f"Optimized schedule for {job_name}: {old_schedule} -> {new_schedule}")
            
        return success
    
    def update_crontab(self, job_name: str, new_schedule: str) -> bool:
        """Update crontab with new schedule"""
        try:
            # Get current crontab
            result = subprocess.run(['crontab', '-l'], capture_output=True, text=True)
            current_cron = result.stdout if result.returncode == 0 else ""
            
            # Update the specific job
            lines = current_cron.split('\n')
            updated_lines = []
            
            for line in lines:
                if job_name in line and not line.startswith('#'):
                    # Replace schedule
                    parts = line.split(None, 5)
                    if len(parts) == 6:
                        new_parts = new_schedule.split() + [parts[5]]
                        line = ' '.join(new_parts)
                updated_lines.append(line)
            
            # Write back
            new_cron = '\n'.join(updated_lines)
            proc = subprocess.Popen(['crontab', '-'], stdin=subprocess.PIPE)
            proc.communicate(new_cron.encode())
            
            return proc.returncode == 0
            
        except Exception as e:
            self.logger.error(f"Failed to update crontab: {e}")
            return False
    
    def generate_optimization_report(self) -> str:
        """Generate detailed optimization report"""
        trends = self.analyze_performance_trends()
        
        report = f"""# Intelligent Cron Scheduler Report
Generated: {datetime.now().isoformat()}

## System Overview
- Total Jobs: {len(self.jobs)}
- Overall Health: {trends['overall_health']}
- Problem Jobs: {len(trends['problem_jobs'])}
- Optimization Opportunities: {len(trends['optimization_opportunities'])}

## Job Performance Summary
"""
        
        for job_name, job in sorted(self.jobs.items()):
            report += f"\n### {job_name}\n"
            report += f"- Schedule: `{job.current_schedule}`\n"
            report += f"- Success Rate: {job.performance_metrics['success_rate']:.1%}\n"
            report += f"- Avg Duration: {job.performance_metrics['avg_duration']:.1f}s\n"
            
            if job.performance_metrics['optimal_times']:
                report += f"- Optimal Hours: {job.performance_metrics['optimal_times']}\n"
        
        if trends['problem_jobs']:
            report += "\n## ⚠️ Problem Jobs\n"
            for problem in trends['problem_jobs']:
                report += f"- **{problem['name']}**: {problem['success_rate']:.1%} success rate\n"
                report += f"  - Suggestion: {problem['suggestion']}\n"
        
        if trends['optimization_opportunities']:
            report += "\n## 🚀 Optimization Opportunities\n"
            for opp in trends['optimization_opportunities']:
                report += f"\n### {opp['job']}\n"
                report += f"- Current: `{opp['current_schedule']}`\n"
                report += f"- Suggested: `{opp['suggested_schedule']}`\n"
                report += f"- Reason: {opp['reason']}\n"
        
        if trends['system_patterns']:
            report += "\n## System Patterns\n"
            if trends['system_patterns'].get('peak_hours'):
                report += f"- Peak Hours: {trends['system_patterns']['peak_hours']}\n"
            if trends['system_patterns'].get('recommended_quiet_hours'):
                quiet = trends['system_patterns']['recommended_quiet_hours'][:5]
                report += f"- Recommended Quiet Hours: {quiet}\n"
        
        report += "\n## Recommendations\n"
        report += "1. Review and apply suggested schedule optimizations\n"
        report += "2. Investigate failing jobs for root causes\n"
        report += "3. Consider spreading jobs across quiet hours\n"
        report += "4. Monitor system load during peak hours\n"
        
        return report
    
    def run(self):
        """Main run method"""
        self.logger.info("Intelligent Cron Scheduler analyzing job performance")
        
        try:
            # Simulate monitoring some job executions
            for job_name, job in list(self.jobs.items())[:3]:  # Monitor first 3 jobs
                self.logger.info(f"Monitoring execution of {job_name}")
                result = self.monitor_job_execution(job)
                self.logger.info(f"Execution result: {result}")
            
            # Analyze trends
            trends = self.analyze_performance_trends()
            
            # Apply optimizations if confidence is high
            for opp in trends['optimization_opportunities']:
                if len(self.jobs[opp['job']].execution_history) >= 20:
                    self.logger.info(f"Applying optimization for {opp['job']}")
                    self.apply_schedule_optimization(opp['job'], opp['suggested_schedule'])
            
            # Generate and save report
            report = self.generate_optimization_report()
            report_path = CDCS_PATH / "automation" / "reports" / f"cron_optimization_{int(time.time())}.md"
            report_path.parent.mkdir(exist_ok=True, parents=True)
            report_path.write_text(report)
            
            self.logger.info(f"Generated optimization report: {report_path}")
            
            # Save current state
            self.save_job_states()
            
        except Exception as e:
            self.logger.error(f"Intelligent scheduler error: {e}")
    
    def save_job_states(self):
        """Save current job states for persistence"""
        states = {}
        
        for job_name, job in self.jobs.items():
            states[job_name] = {
                'current_schedule': job.current_schedule,
                'performance_metrics': job.performance_metrics,
                'last_adjustment': job.last_adjustment.isoformat()
            }
        
        state_path = CDCS_PATH / "automation" / "cron_job_states.json"
        state_path.write_text(json.dumps(states, indent=2))

if __name__ == "__main__":
    # Test run
    from cdcs_orchestrator import CDCSOrchestrator
    orchestrator = CDCSOrchestrator()
    scheduler = IntelligentCronScheduler(orchestrator)
    scheduler.run()

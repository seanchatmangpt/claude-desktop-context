#!/usr/bin/env python3
"""
System Health Monitor Agent - Monitors CDCS health and performance
Uses ollama/qwen3 for intelligent anomaly detection and diagnostics
"""

import json
import psutil
import os
from pathlib import Path
from typing import Dict, List, Tuple
import datetime
import numpy as np
from collections import deque

class SystemHealthMonitor:
    def __init__(self, orchestrator):
        self.orchestrator = orchestrator
        self.task_description = "Monitoring system health"
        self.health_path = Path("/Users/sac/claude-desktop-context/health")
        self.health_path.mkdir(parents=True, exist_ok=True)
        self.alert_thresholds = {
            'disk_usage': 0.8,  # 80%
            'memory_pressure': 0.85,  # 85%
            'error_rate': 0.1,  # 10%
            'performance_degradation': 0.3,  # 30% slower
            'pattern_failure_rate': 0.2  # 20% failures
        }
        
    def check_disk_usage(self) -> Dict:
        """Monitor disk usage for CDCS directory"""
        
        cdcs_path = Path("/Users/sac/claude-desktop-context")
        
        # Calculate directory size
        total_size = 0
        file_count = 0
        largest_files = []
        
        for path in cdcs_path.rglob('*'):
            if path.is_file():
                size = path.stat().st_size
                total_size += size
                file_count += 1
                
                largest_files.append((path, size))
                
        # Sort and get top 10 largest
        largest_files.sort(key=lambda x: x[1], reverse=True)
        largest_files = largest_files[:10]
        
        # Get disk statistics
        disk_usage = psutil.disk_usage(str(cdcs_path))
        
        health_status = {
            'total_size_mb': total_size / (1024 * 1024),
            'file_count': file_count,
            'disk_percent_used': disk_usage.percent / 100,
            'disk_free_gb': disk_usage.free / (1024**3),
            'largest_files': [
                {
                    'path': str(f[0].relative_to(cdcs_path)),
                    'size_mb': f[1] / (1024 * 1024)
                }
                for f in largest_files
            ],
            'status': 'healthy' if disk_usage.percent / 100 < self.alert_thresholds['disk_usage'] else 'warning'
        }
        
        return health_status
        
    def analyze_memory_patterns(self) -> Dict:
        """Analyze memory usage patterns"""
        
        memory_stats = {
            'current_usage': {},
            'patterns': {},
            'recommendations': []
        }
        
        # Current memory usage
        memory = psutil.virtual_memory()
        memory_stats['current_usage'] = {
            'total_gb': memory.total / (1024**3),
            'used_gb': memory.used / (1024**3),
            'available_gb': memory.available / (1024**3),
            'percent_used': memory.percent / 100
        }
        
        # Analyze session memory patterns
        import sqlite3
        conn = sqlite3.connect(self.orchestrator.db_path)
        
        # Get memory-related metrics
        memory_metrics = conn.execute("""
            SELECT AVG(compression_achieved) as avg_compression,
                   MAX(tokens_processed) as max_tokens,
                   COUNT(*) as run_count
            FROM automation_runs
            WHERE agent = 'memory_optimizer'
            AND timestamp > datetime('now', '-7 days')
        """).fetchone()
        
        if memory_metrics:
            memory_stats['patterns'] = {
                'avg_compression_ratio': memory_metrics[0] or 1.0,
                'max_tokens_processed': memory_metrics[1] or 0,
                'optimization_runs': memory_metrics[2]
            }
            
        # Generate recommendations
        if memory_stats['current_usage']['percent_used'] > self.alert_thresholds['memory_pressure']:
            memory_stats['recommendations'].append({
                'action': 'compress_sessions',
                'urgency': 'high',
                'reason': 'Memory pressure exceeds threshold'
            })
            
        conn.close()
        return memory_stats
        
    def detect_performance_anomalies(self) -> List[Dict]:
        """Detect performance anomalies using ollama"""
        
        anomalies = []
        
        # Get recent performance metrics
        import sqlite3
        conn = sqlite3.connect(self.orchestrator.db_path)
        
        # Compare recent vs historical performance
        recent_metrics = conn.execute("""
            SELECT agent, task, 
                   AVG(tokens_processed) as avg_tokens,
                   AVG(patterns_found) as avg_patterns,
                   AVG(evolution_score) as avg_evolution
            FROM automation_runs
            WHERE timestamp > datetime('now', '-1 day')
            GROUP BY agent, task
        """).fetchall()
        
        historical_metrics = conn.execute("""
            SELECT agent, task,
                   AVG(tokens_processed) as avg_tokens,
                   AVG(patterns_found) as avg_patterns,
                   AVG(evolution_score) as avg_evolution
            FROM automation_runs
            WHERE timestamp BETWEEN datetime('now', '-30 days') AND datetime('now', '-1 day')
            GROUP BY agent, task
        """).fetchall()
        
        # Build comparison map
        historical_map = {
            f"{h[0]}_{h[1]}": {'tokens': h[2], 'patterns': h[3], 'evolution': h[4]}
            for h in historical_metrics
        }
        
        # Check for anomalies
        for agent, task, tokens, patterns, evolution in recent_metrics:
            key = f"{agent}_{task}"
            
            if key in historical_map:
                hist = historical_map[key]
                
                # Calculate deviations
                token_deviation = abs(tokens - hist['tokens']) / (hist['tokens'] + 1)
                pattern_deviation = abs(patterns - hist['patterns']) / (hist['patterns'] + 1) if hist['patterns'] else 0
                
                if token_deviation > self.alert_thresholds['performance_degradation']:
                    anomalies.append({
                        'type': 'performance',
                        'component': agent,
                        'task': task,
                        'metric': 'token_processing',
                        'current': tokens,
                        'historical': hist['tokens'],
                        'deviation': token_deviation,
                        'severity': 'high' if token_deviation > 0.5 else 'medium'
                    })
                    
        # Use ollama to analyze anomalies
        if anomalies:
            system_prompt = """Analyze these performance anomalies and suggest root causes.
            Output JSON:
            {
                "analysis": "overall assessment",
                "likely_causes": ["cause1", "cause2"],
                "recommendations": ["action1", "action2"]
            }
            """
            
            prompt = f"Analyze anomalies: {json.dumps(anomalies[:5])}"
            response = self.orchestrator.ollama_query(prompt, system_prompt)
            
            try:
                analysis = json.loads(response)
                for anomaly in anomalies:
                    anomaly['analysis'] = analysis
            except:
                pass
                
        conn.close()
        return anomalies
        
    def check_pattern_health(self) -> Dict:
        """Monitor pattern system health"""
        
        pattern_health = {
            'total_patterns': 0,
            'active_patterns': 0,
            'success_rate': 0.0,
            'failing_patterns': [],
            'unused_patterns': []
        }
        
        import sqlite3
        conn = sqlite3.connect(self.orchestrator.db_path)
        
        # Get pattern statistics
        pattern_stats = conn.execute("""
            SELECT COUNT(*) as total,
                   COUNT(CASE WHEN usage_count > 0 THEN 1 END) as used,
                   COUNT(CASE WHEN confidence < 0.5 THEN 1 END) as low_confidence
            FROM discovered_patterns
        """).fetchone()
        
        if pattern_stats:
            pattern_health['total_patterns'] = pattern_stats[0]
            pattern_health['active_patterns'] = pattern_stats[1]
            
            if pattern_stats[0] > 0:
                pattern_health['success_rate'] = pattern_stats[1] / pattern_stats[0]
                
        # Find failing patterns
        failing = conn.execute("""
            SELECT pattern_hash, pattern_content, confidence
            FROM discovered_patterns
            WHERE confidence < 0.5
            AND usage_count > 0
            ORDER BY confidence
            LIMIT 5
        """).fetchall()
        
        for pattern_hash, content, confidence in failing:
            try:
                pattern_data = json.loads(content)
                pattern_health['failing_patterns'].append({
                    'name': pattern_data.get('name', 'unknown'),
                    'confidence': confidence,
                    'hash': pattern_hash
                })
            except:
                pass
                
        # Find unused patterns (older than 7 days)
        unused = conn.execute("""
            SELECT pattern_hash, pattern_content
            FROM discovered_patterns
            WHERE usage_count = 0
            AND julianday('now') - julianday(timestamp) > 7
            LIMIT 10
        """).fetchall()
        
        for pattern_hash, content in unused:
            try:
                pattern_data = json.loads(content)
                pattern_health['unused_patterns'].append({
                    'name': pattern_data.get('name', 'unknown'),
                    'hash': pattern_hash
                })
            except:
                pass
                
        conn.close()
        return pattern_health
        
    def analyze_error_logs(self) -> Dict:
        """Analyze error patterns in logs"""
        
        error_analysis = {
            'error_count': 0,
            'error_types': {},
            'error_trends': [],
            'critical_errors': []
        }
        
        logs_path = self.orchestrator.automation_path / "logs"
        if not logs_path.exists():
            return error_analysis
            
        # Analyze recent log files
        import re
        error_pattern = re.compile(r'(\d{4}-\d{2}-\d{2}.*?)\s+(ERROR|WARNING|CRITICAL):\s*(.+?)(?:\n|$)')
        
        recent_errors = []
        for log_file in sorted(logs_path.glob("*.log"), key=lambda x: x.stat().st_mtime, reverse=True)[:5]:
            content = log_file.read_text()
            
            matches = error_pattern.findall(content)
            for timestamp, level, message in matches:
                recent_errors.append({
                    'timestamp': timestamp,
                    'level': level,
                    'message': message[:200],  # Truncate
                    'file': log_file.name
                })
                
                # Count by type
                error_type = message.split(':')[0] if ':' in message else 'general'
                error_analysis['error_types'][error_type] = error_analysis['error_types'].get(error_type, 0) + 1
                
                if level == 'CRITICAL':
                    error_analysis['critical_errors'].append({
                        'timestamp': timestamp,
                        'message': message[:200]
                    })
                    
        error_analysis['error_count'] = len(recent_errors)
        
        # Calculate error trends
        if recent_errors:
            # Group by hour
            hourly_errors = {}
            for error in recent_errors:
                try:
                    dt = datetime.datetime.fromisoformat(error['timestamp'])
                    hour_key = dt.strftime('%Y-%m-%d %H:00')
                    hourly_errors[hour_key] = hourly_errors.get(hour_key, 0) + 1
                except:
                    pass
                    
            error_analysis['error_trends'] = [
                {'hour': k, 'count': v}
                for k, v in sorted(hourly_errors.items())[-24:]  # Last 24 hours
            ]
            
        return error_analysis
        
    def generate_health_report(self, all_metrics: Dict) -> Dict:
        """Generate comprehensive health report using ollama"""
        
        system_prompt = """Analyze the CDCS system health metrics and generate a comprehensive report.
        
        Output JSON:
        {
            "overall_health": "healthy|warning|critical",
            "health_score": 0.0-1.0,
            "issues": [
                {
                    "component": "component name",
                    "issue": "description",
                    "severity": "low|medium|high",
                    "recommendation": "action to take"
                }
            ],
            "trends": {
                "improving": ["metric1", "metric2"],
                "degrading": ["metric3", "metric4"],
                "stable": ["metric5"]
            },
            "predictions": [
                {
                    "metric": "metric name",
                    "prediction": "expected change",
                    "timeframe": "when"
                }
            ]
        }
        """
        
        prompt = f"Generate health report from metrics:\n{json.dumps(all_metrics, indent=2)[:2000]}"
        response = self.orchestrator.ollama_query(prompt, system_prompt)
        
        try:
            report = json.loads(response)
            report['generated_at'] = datetime.datetime.now().isoformat()
            return report
        except:
            # Fallback report
            return {
                'overall_health': 'unknown',
                'health_score': 0.5,
                'issues': [],
                'generated_at': datetime.datetime.now().isoformat()
            }
            
    def save_health_snapshot(self, health_data: Dict):
        """Save health snapshot for historical tracking"""
        
        snapshot_file = self.health_path / f"health_snapshot_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        snapshot_file.write_text(json.dumps(health_data, indent=2))
        
        # Update current health pointer
        current_health = self.health_path / "current_health.json"
        current_health.write_text(json.dumps({
            'snapshot': str(snapshot_file),
            'timestamp': datetime.datetime.now().isoformat(),
            'overall_health': health_data['report']['overall_health'],
            'health_score': health_data['report']['health_score']
        }, indent=2))
        
    def run(self) -> Dict:
        """Execute system health monitoring"""
        metrics = {
            'tokens_processed': 0,
            'issues_detected': 0,
            'health_score': 1.0,
            'metadata': {}
        }
        
        all_health_metrics = {}
        
        # 1. Check disk usage
        disk_health = self.check_disk_usage()
        all_health_metrics['disk'] = disk_health
        
        # 2. Analyze memory patterns
        memory_health = self.analyze_memory_patterns()
        all_health_metrics['memory'] = memory_health
        
        # 3. Detect performance anomalies
        anomalies = self.detect_performance_anomalies()
        all_health_metrics['anomalies'] = anomalies
        metrics['issues_detected'] += len(anomalies)
        
        # 4. Check pattern health
        pattern_health = self.check_pattern_health()
        all_health_metrics['patterns'] = pattern_health
        
        # 5. Analyze error logs
        error_analysis = self.analyze_error_logs()
        all_health_metrics['errors'] = error_analysis
        metrics['issues_detected'] += error_analysis['error_count']
        
        # Generate comprehensive health report
        health_report = self.generate_health_report(all_health_metrics)
        all_health_metrics['report'] = health_report
        
        metrics['health_score'] = health_report.get('health_score', 0.5)
        metrics['tokens_processed'] = 1000  # Approximate for analysis
        
        # Save health snapshot
        self.save_health_snapshot(all_health_metrics)
        
        # Prepare metadata
        metrics['metadata'] = {
            'disk_usage_percent': disk_health['disk_percent_used'] * 100,
            'memory_usage_percent': memory_health['current_usage']['percent_used'] * 100,
            'pattern_success_rate': pattern_health['success_rate'],
            'error_count': error_analysis['error_count'],
            'anomaly_count': len(anomalies),
            'overall_health': health_report['overall_health'],
            'critical_issues': len([i for i in health_report.get('issues', []) if i['severity'] == 'high'])
        }
        
        return metrics

#!/usr/bin/env python3
"""
CDCS Telemetry Aggregator and Dashboard
Real-time telemetry analysis and visualization for CDCS automation
"""

import os
import sys
import json
import time
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
from collections import defaultdict, deque
import statistics
import logging
from dataclasses import dataclass
import threading

# Try to import visualization libraries
try:
    import matplotlib.pyplot as plt
    import matplotlib.animation as animation
    from matplotlib.figure import Figure
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False

# Add CDCS path
CDCS_PATH = Path("/Users/sac/claude-desktop-context")
sys.path.append(str(CDCS_PATH / "automation"))
sys.path.append(str(CDCS_PATH / "automation" / "advanced_loops"))

from otel_base_agent import OTelBaseAgent, instrument_function

@dataclass
class MetricPoint:
    """Single metric data point"""
    timestamp: datetime
    value: float
    labels: Dict[str, str]
    
@dataclass
class TraceSpan:
    """Simplified trace span representation"""
    trace_id: str
    span_id: str
    name: str
    start_time: datetime
    end_time: datetime
    duration_ms: float
    status: str
    attributes: Dict[str, Any]
    
class TelemetryAggregator(OTelBaseAgent):
    """
    Aggregates and analyzes telemetry data from CDCS automation components
    """
    
    def __init__(self, orchestrator):
        super().__init__(orchestrator, "TelemetryAggregator")
        self.telemetry_db = CDCS_PATH / "automation" / "telemetry" / "aggregated_metrics.db"
        self.init_telemetry_db()
        
        # In-memory stores for real-time analysis
        self.metric_buffers = defaultdict(lambda: deque(maxlen=1000))
        self.trace_buffer = deque(maxlen=500)
        self.alert_conditions = self.load_alert_conditions()
        
        # Aggregation state
        self.aggregation_windows = {
            '1m': timedelta(minutes=1),
            '5m': timedelta(minutes=5),
            '15m': timedelta(minutes=15),
            '1h': timedelta(hours=1),
            '24h': timedelta(hours=24)
        }
        
        # Dashboard update thread
        self.dashboard_running = False
        self.dashboard_thread = None
        
    def init_telemetry_db(self):
        """Initialize telemetry aggregation database"""
        self.telemetry_db.parent.mkdir(exist_ok=True, parents=True)
        
        conn = sqlite3.connect(self.telemetry_db)
        
        # Metrics table
        conn.execute('''
            CREATE TABLE IF NOT EXISTS metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                metric_name TEXT,
                timestamp TIMESTAMP,
                value REAL,
                labels TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Traces table
        conn.execute('''
            CREATE TABLE IF NOT EXISTS traces (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                trace_id TEXT,
                span_id TEXT,
                span_name TEXT,
                start_time TIMESTAMP,
                end_time TIMESTAMP,
                duration_ms REAL,
                status TEXT,
                attributes TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Aggregated metrics table
        conn.execute('''
            CREATE TABLE IF NOT EXISTS aggregated_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                metric_name TEXT,
                window TEXT,
                timestamp TIMESTAMP,
                count INTEGER,
                sum REAL,
                min REAL,
                max REAL,
                avg REAL,
                p50 REAL,
                p95 REAL,
                p99 REAL,
                labels TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Alerts table
        conn.execute('''
            CREATE TABLE IF NOT EXISTS alerts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                alert_name TEXT,
                severity TEXT,
                condition TEXT,
                triggered_at TIMESTAMP,
                resolved_at TIMESTAMP,
                details TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Create indices for performance
        conn.execute('CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON metrics(timestamp)')
        conn.execute('CREATE INDEX IF NOT EXISTS idx_traces_timestamp ON traces(start_time)')
        conn.execute('CREATE INDEX IF NOT EXISTS idx_aggregated_window ON aggregated_metrics(window, timestamp)')
        
        conn.commit()
        conn.close()
        
    def load_alert_conditions(self) -> List[Dict]:
        """Load alert conditions from configuration"""
        return [
            {
                'name': 'high_error_rate',
                'metric': 'cdcs.agent.errors',
                'condition': 'rate_5m > 0.1',
                'severity': 'warning',
                'description': 'Error rate exceeds 10% over 5 minutes'
            },
            {
                'name': 'low_pattern_detection',
                'metric': 'cdcs.patterns.detected',
                'condition': 'count_1h < 5',
                'severity': 'info',
                'description': 'Fewer than 5 patterns detected in the last hour'
            },
            {
                'name': 'slow_execution',
                'metric': 'cdcs.agent.execution.duration',
                'condition': 'p95 > 10',
                'severity': 'warning',
                'description': '95th percentile execution time exceeds 10 seconds'
            },
            {
                'name': 'system_unhealthy',
                'metric': 'cdcs.system.health',
                'condition': 'value < 70',
                'severity': 'critical',
                'description': 'System health score below 70%'
            }
        ]
        
    @instrument_function()
    def ingest_metrics(self, metrics: List[Dict]):
        """Ingest metrics from OTLP export"""
        conn = sqlite3.connect(self.telemetry_db)
        
        for metric in metrics:
            # Store in database
            conn.execute('''
                INSERT INTO metrics (metric_name, timestamp, value, labels)
                VALUES (?, ?, ?, ?)
            ''', (
                metric['name'],
                metric['timestamp'],
                metric['value'],
                json.dumps(metric.get('labels', {}))
            ))
            
            # Buffer for real-time analysis
            point = MetricPoint(
                timestamp=datetime.fromisoformat(metric['timestamp']),
                value=metric['value'],
                labels=metric.get('labels', {})
            )
            self.metric_buffers[metric['name']].append(point)
            
        conn.commit()
        conn.close()
        
        # Check alerts
        self.check_alerts()
        
    @instrument_function()
    def ingest_traces(self, traces: List[Dict]):
        """Ingest trace data from OTLP export"""
        conn = sqlite3.connect(self.telemetry_db)
        
        for trace in traces:
            # Store in database
            conn.execute('''
                INSERT INTO traces 
                (trace_id, span_id, span_name, start_time, end_time, duration_ms, status, attributes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                trace['trace_id'],
                trace['span_id'],
                trace['name'],
                trace['start_time'],
                trace['end_time'],
                trace['duration_ms'],
                trace['status'],
                json.dumps(trace.get('attributes', {}))
            ))
            
            # Buffer for real-time analysis
            span = TraceSpan(
                trace_id=trace['trace_id'],
                span_id=trace['span_id'],
                name=trace['name'],
                start_time=datetime.fromisoformat(trace['start_time']),
                end_time=datetime.fromisoformat(trace['end_time']),
                duration_ms=trace['duration_ms'],
                status=trace['status'],
                attributes=trace.get('attributes', {})
            )
            self.trace_buffer.append(span)
            
        conn.commit()
        conn.close()
        
    def aggregate_metrics(self, window: str):
        """Aggregate metrics for a specific time window"""
        if window not in self.aggregation_windows:
            return
            
        window_delta = self.aggregation_windows[window]
        now = datetime.now()
        window_start = now - window_delta
        
        conn = sqlite3.connect(self.telemetry_db)
        
        # Get metrics for aggregation
        cursor = conn.execute('''
            SELECT metric_name, value, labels
            FROM metrics
            WHERE timestamp >= ?
        ''', (window_start.isoformat(),))
        
        # Group by metric name and labels
        metric_groups = defaultdict(list)
        for row in cursor:
            metric_name, value, labels_json = row
            key = (metric_name, labels_json)
            metric_groups[key].append(value)
        
        # Calculate aggregations
        for (metric_name, labels_json), values in metric_groups.items():
            if not values:
                continue
                
            sorted_values = sorted(values)
            
            aggregation = {
                'count': len(values),
                'sum': sum(values),
                'min': min(values),
                'max': max(values),
                'avg': statistics.mean(values),
                'p50': sorted_values[len(values)//2],
                'p95': sorted_values[int(len(values)*0.95)],
                'p99': sorted_values[int(len(values)*0.99)]
            }
            
            # Store aggregation
            conn.execute('''
                INSERT INTO aggregated_metrics
                (metric_name, window, timestamp, count, sum, min, max, avg, p50, p95, p99, labels)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                metric_name,
                window,
                now.isoformat(),
                aggregation['count'],
                aggregation['sum'],
                aggregation['min'],
                aggregation['max'],
                aggregation['avg'],
                aggregation['p50'],
                aggregation['p95'],
                aggregation['p99'],
                labels_json
            ))
            
        conn.commit()
        conn.close()
        
    def check_alerts(self):
        """Check alert conditions and trigger if necessary"""
        now = datetime.now()
        
        for condition in self.alert_conditions:
            metric_name = condition['metric']
            
            # Get recent metric values
            if metric_name in self.metric_buffers:
                recent_points = list(self.metric_buffers[metric_name])
                
                # Simple condition evaluation (would be more sophisticated in practice)
                if 'rate_5m' in condition['condition']:
                    # Calculate 5-minute rate
                    five_min_ago = now - timedelta(minutes=5)
                    recent_values = [p.value for p in recent_points 
                                   if p.timestamp >= five_min_ago]
                    
                    if recent_values:
                        rate = sum(recent_values) / (5 * 60)  # per second
                        threshold = float(condition['condition'].split('>')[-1])
                        
                        if rate > threshold:
                            self.trigger_alert(condition, {
                                'rate': rate,
                                'threshold': threshold
                            })
                            
                elif 'count_1h' in condition['condition']:
                    # Count in last hour
                    one_hour_ago = now - timedelta(hours=1)
                    count = sum(1 for p in recent_points 
                               if p.timestamp >= one_hour_ago)
                    
                    threshold = int(condition['condition'].split('<')[-1])
                    
                    if count < threshold:
                        self.trigger_alert(condition, {
                            'count': count,
                            'threshold': threshold
                        })
                        
    def trigger_alert(self, condition: Dict, details: Dict):
        """Trigger an alert"""
        conn = sqlite3.connect(self.telemetry_db)
        
        # Check if alert already active
        cursor = conn.execute('''
            SELECT id FROM alerts
            WHERE alert_name = ? AND resolved_at IS NULL
            ORDER BY triggered_at DESC
            LIMIT 1
        ''', (condition['name'],))
        
        active_alert = cursor.fetchone()
        
        if not active_alert:
            # Create new alert
            conn.execute('''
                INSERT INTO alerts (alert_name, severity, condition, triggered_at, details)
                VALUES (?, ?, ?, ?, ?)
            ''', (
                condition['name'],
                condition['severity'],
                condition['condition'],
                datetime.now().isoformat(),
                json.dumps(details)
            ))
            
            self.logger.warning(f"Alert triggered: {condition['name']} - {condition['description']}")
            
            # Record alert event
            self.add_span_event(
                "alert_triggered",
                {
                    "alert.name": condition['name'],
                    "alert.severity": condition['severity'],
                    "alert.details": json.dumps(details)
                }
            )
            
        conn.commit()
        conn.close()
        
    def generate_dashboard_data(self) -> Dict:
        """Generate data for dashboard display"""
        now = datetime.now()
        data = {
            'timestamp': now.isoformat(),
            'metrics': {},
            'traces': {},
            'alerts': [],
            'health': {}
        }
        
        # Get recent metrics
        for metric_name, buffer in self.metric_buffers.items():
            recent = list(buffer)[-100:]  # Last 100 points
            if recent:
                data['metrics'][metric_name] = {
                    'timestamps': [p.timestamp.isoformat() for p in recent],
                    'values': [p.value for p in recent],
                    'current': recent[-1].value,
                    'avg_1m': statistics.mean([p.value for p in recent[-10:]]) if len(recent) >= 10 else recent[-1].value
                }
        
        # Get trace statistics
        recent_traces = list(self.trace_buffer)
        if recent_traces:
            # Group by span name
            span_stats = defaultdict(list)
            for span in recent_traces:
                span_stats[span.name].append(span.duration_ms)
                
            data['traces'] = {
                name: {
                    'count': len(durations),
                    'avg_duration': statistics.mean(durations),
                    'p95_duration': sorted(durations)[int(len(durations)*0.95)] if durations else 0
                }
                for name, durations in span_stats.items()
            }
        
        # Get active alerts
        conn = sqlite3.connect(self.telemetry_db)
        cursor = conn.execute('''
            SELECT alert_name, severity, condition, triggered_at, details
            FROM alerts
            WHERE resolved_at IS NULL
            ORDER BY triggered_at DESC
        ''')
        
        for row in cursor:
            data['alerts'].append({
                'name': row[0],
                'severity': row[1],
                'condition': row[2],
                'triggered_at': row[3],
                'details': json.loads(row[4])
            })
        
        conn.close()
        
        # Calculate overall health
        health_score = 100
        
        # Deduct for active alerts
        for alert in data['alerts']:
            if alert['severity'] == 'critical':
                health_score -= 30
            elif alert['severity'] == 'warning':
                health_score -= 15
            elif alert['severity'] == 'info':
                health_score -= 5
                
        # Factor in error rate
        if 'cdcs.agent.errors' in data['metrics']:
            error_rate = data['metrics']['cdcs.agent.errors']['avg_1m']
            health_score -= min(error_rate * 100, 20)  # Max 20 point deduction
            
        data['health']['score'] = max(health_score, 0)
        data['health']['status'] = 'healthy' if health_score >= 80 else 'degraded' if health_score >= 50 else 'unhealthy'
        
        return data
        
    def start_dashboard(self):
        """Start the real-time dashboard"""
        if HAS_MATPLOTLIB:
            self.dashboard_running = True
            self.dashboard_thread = threading.Thread(target=self._run_matplotlib_dashboard)
            self.dashboard_thread.start()
        else:
            self.logger.warning("Matplotlib not available. Using text-based dashboard.")
            self._run_text_dashboard()
            
    def _run_matplotlib_dashboard(self):
        """Run matplotlib-based dashboard"""
        fig, axes = plt.subplots(2, 2, figsize=(12, 8))
        fig.suptitle('CDCS Telemetry Dashboard')
        
        def update_plots(frame):
            data = self.generate_dashboard_data()
            
            # Clear axes
            for ax in axes.flat:
                ax.clear()
                
            # Plot 1: Agent executions
            ax1 = axes[0, 0]
            if 'cdcs.agent.executions' in data['metrics']:
                metric = data['metrics']['cdcs.agent.executions']
                timestamps = [datetime.fromisoformat(t) for t in metric['timestamps']]
                ax1.plot(timestamps, metric['values'])
                ax1.set_title('Agent Executions')
                ax1.set_ylabel('Count')
                
            # Plot 2: System health
            ax2 = axes[0, 1]
            health_score = data['health']['score']
            ax2.bar(['Health Score'], [health_score])
            ax2.set_ylim(0, 100)
            ax2.set_title(f"System Health: {data['health']['status']}")
            
            # Plot 3: Trace durations
            ax3 = axes[1, 0]
            if data['traces']:
                names = list(data['traces'].keys())[:5]  # Top 5
                durations = [data['traces'][n]['avg_duration'] for n in names]
                ax3.barh(names, durations)
                ax3.set_xlabel('Avg Duration (ms)')
                ax3.set_title('Trace Durations')
                
            # Plot 4: Active alerts
            ax4 = axes[1, 1]
            if data['alerts']:
                alert_text = "Active Alerts:\n"
                for alert in data['alerts'][:5]:
                    alert_text += f"- {alert['name']} ({alert['severity']})\n"
            else:
                alert_text = "No active alerts"
            ax4.text(0.1, 0.5, alert_text, transform=ax4.transAxes, fontsize=10)
            ax4.set_title('Alerts')
            ax4.axis('off')
            
            plt.tight_layout()
            
        ani = animation.FuncAnimation(fig, update_plots, interval=5000)  # Update every 5 seconds
        plt.show()
        
    def _run_text_dashboard(self):
        """Run text-based dashboard"""
        while self.dashboard_running:
            os.system('clear' if os.name == 'posix' else 'cls')
            
            data = self.generate_dashboard_data()
            
            print("=" * 80)
            print(f"CDCS Telemetry Dashboard - {data['timestamp']}")
            print("=" * 80)
            
            # System health
            print(f"\nSystem Health: {data['health']['status']} (Score: {data['health']['score']:.0f}/100)")
            
            # Key metrics
            print("\nKey Metrics:")
            for metric_name, metric_data in data['metrics'].items():
                print(f"  {metric_name}: {metric_data['current']:.2f} (1m avg: {metric_data['avg_1m']:.2f})")
                
            # Top traces
            print("\nTop Operations by Duration:")
            sorted_traces = sorted(data['traces'].items(), 
                                 key=lambda x: x[1]['avg_duration'], 
                                 reverse=True)[:5]
            for name, stats in sorted_traces:
                print(f"  {name}: {stats['avg_duration']:.1f}ms (p95: {stats['p95_duration']:.1f}ms)")
                
            # Active alerts
            print(f"\nActive Alerts ({len(data['alerts'])}):")
            if data['alerts']:
                for alert in data['alerts']:
                    print(f"  [{alert['severity'].upper()}] {alert['name']}")
            else:
                print("  No active alerts")
                
            print("\nPress Ctrl+C to exit...")
            time.sleep(5)
            
    def run(self):
        """Main aggregation loop"""
        with self.start_span("telemetry_aggregation") as span:
            self.logger.info("Starting telemetry aggregation")
            
            try:
                # Start dashboard
                self.start_dashboard()
                
                # Aggregation loop
                while True:
                    # Aggregate metrics for all windows
                    for window in self.aggregation_windows:
                        self.aggregate_metrics(window)
                        
                    # Clean old data
                    self.cleanup_old_data()
                    
                    # Sleep until next aggregation
                    time.sleep(60)  # Aggregate every minute
                    
            except KeyboardInterrupt:
                self.logger.info("Stopping telemetry aggregation")
                self.dashboard_running = False
                if self.dashboard_thread:
                    self.dashboard_thread.join()
                    
    def cleanup_old_data(self):
        """Clean up old telemetry data"""
        conn = sqlite3.connect(self.telemetry_db)
        
        # Keep raw metrics for 24 hours
        conn.execute('''
            DELETE FROM metrics
            WHERE timestamp < datetime('now', '-1 day')
        ''')
        
        # Keep traces for 7 days
        conn.execute('''
            DELETE FROM traces
            WHERE start_time < datetime('now', '-7 days')
        ''')
        
        # Keep aggregated metrics based on window
        for window, retention in [('1m', '-1 day'), ('5m', '-3 days'), 
                                  ('15m', '-7 days'), ('1h', '-30 days'), 
                                  ('24h', '-90 days')]:
            conn.execute('''
                DELETE FROM aggregated_metrics
                WHERE window = ? AND timestamp < datetime('now', ?)
            ''', (window, retention))
            
        conn.commit()
        conn.close()

if __name__ == "__main__":
    # Test telemetry aggregator
    from cdcs_orchestrator import CDCSOrchestrator
    
    orchestrator = CDCSOrchestrator()
    aggregator = TelemetryAggregator(orchestrator)
    
    # Simulate some metrics
    test_metrics = [
        {
            'name': 'cdcs.agent.executions',
            'timestamp': datetime.now().isoformat(),
            'value': 5,
            'labels': {'agent': 'TerminalOrchestrator'}
        },
        {
            'name': 'cdcs.patterns.detected',
            'timestamp': datetime.now().isoformat(),
            'value': 2,
            'labels': {'pattern_type': 'bulk_operation'}
        }
    ]
    
    aggregator.ingest_metrics(test_metrics)
    
    # Run dashboard
    aggregator.run()

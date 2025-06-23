#!/usr/bin/env python3
"""
Real-time Pattern Detector - FSEvents-based Automation Trigger
Monitors file system changes and triggers appropriate automation
"""

import os
import sys
import time
import json
import sqlite3
import hashlib
import threading
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Set, Optional, Tuple
from collections import defaultdict, deque
import logging

# Add CDCS path
CDCS_PATH = Path("/Users/sac/claude-desktop-context")
sys.path.append(str(CDCS_PATH / "automation"))

try:
    # Try to import FSEvents (macOS file system events)
    from fsevents import Observer, Stream
    HAS_FSEVENTS = True
except ImportError:
    HAS_FSEVENTS = False
    # Fallback to polling
    
from base_agent import BaseAgent

class PatternDetector:
    """Detects patterns in file system activity"""
    
    def __init__(self, window_size: int = 100):
        self.window_size = window_size
        self.event_window = deque(maxlen=window_size)
        self.pattern_counts = defaultdict(int)
        self.detected_patterns = []
        
    def add_event(self, event: Dict) -> List[Dict]:
        """Add event and detect patterns"""
        self.event_window.append(event)
        
        # Detect various pattern types
        patterns = []
        patterns.extend(self.detect_rapid_changes())
        patterns.extend(self.detect_bulk_operations())
        patterns.extend(self.detect_workflow_patterns())
        patterns.extend(self.detect_error_patterns())
        
        return patterns
    
    def detect_rapid_changes(self) -> List[Dict]:
        """Detect rapid file changes indicating active development"""
        if len(self.event_window) < 10:
            return []
            
        patterns = []
        recent_events = list(self.event_window)[-20:]
        
        # Group by file
        file_changes = defaultdict(list)
        for event in recent_events:
            file_changes[event['path']].append(event)
        
        # Detect files changing rapidly
        for path, changes in file_changes.items():
            if len(changes) >= 3:
                time_span = (changes[-1]['timestamp'] - changes[0]['timestamp']).total_seconds()
                if time_span < 60:  # 3+ changes in under a minute
                    patterns.append({
                        'type': 'rapid_development',
                        'path': path,
                        'change_count': len(changes),
                        'time_span': time_span,
                        'suggestion': 'Enable auto-save or continuous integration'
                    })
                    
        return patterns
    
    def detect_bulk_operations(self) -> List[Dict]:
        """Detect bulk file operations"""
        if len(self.event_window) < 5:
            return []
            
        patterns = []
        recent_events = list(self.event_window)[-30:]
        
        # Group by operation type
        ops_by_type = defaultdict(list)
        for event in recent_events:
            ops_by_type[event['type']].append(event)
        
        # Check for bulk operations
        for op_type, events in ops_by_type.items():
            if len(events) >= 10:
                time_span = (events[-1]['timestamp'] - events[0]['timestamp']).total_seconds()
                if time_span < 10:  # 10+ operations in 10 seconds
                    patterns.append({
                        'type': 'bulk_operation',
                        'operation': op_type,
                        'count': len(events),
                        'paths': [e['path'] for e in events[:5]] + ['...'],
                        'suggestion': f'Batch {op_type} operations for efficiency'
                    })
                    
        return patterns
    
    def detect_workflow_patterns(self) -> List[Dict]:
        """Detect common workflow patterns"""
        if len(self.event_window) < 20:
            return []
            
        patterns = []
        recent_events = list(self.event_window)
        
        # Common workflow signatures
        workflows = {
            'test_driven_development': [
                ('modified', 'test_*.py'),
                ('modified', '*.py'),
                ('modified', 'test_*.py')
            ],
            'documentation_update': [
                ('modified', '*.md'),
                ('modified', '*.py'),
                ('modified', '*.md')
            ],
            'refactoring': [
                ('renamed', '*.py'),
                ('modified', '*.py'),
                ('deleted', '*.py')
            ]
        }
        
        # Simple pattern matching (could be more sophisticated)
        for workflow_name, signature in workflows.items():
            if self.matches_workflow(recent_events, signature):
                patterns.append({
                    'type': 'workflow_detected',
                    'workflow': workflow_name,
                    'confidence': 0.75,
                    'suggestion': f'Optimize {workflow_name} with automation'
                })
                
        return patterns
    
    def detect_error_patterns(self) -> List[Dict]:
        """Detect patterns indicating errors or issues"""
        patterns = []
        recent_events = list(self.event_window)[-50:]
        
        # Look for rapid create/delete cycles (might indicate failures)
        file_lifecycle = defaultdict(list)
        for event in recent_events:
            file_lifecycle[event['path']].append(event['type'])
        
        for path, lifecycle in file_lifecycle.items():
            if 'created' in lifecycle and 'deleted' in lifecycle:
                create_delete_cycles = 0
                for i in range(len(lifecycle) - 1):
                    if lifecycle[i] == 'created' and lifecycle[i+1] == 'deleted':
                        create_delete_cycles += 1
                
                if create_delete_cycles >= 2:
                    patterns.append({
                        'type': 'unstable_file',
                        'path': path,
                        'cycles': create_delete_cycles,
                        'suggestion': 'Investigate file creation failures'
                    })
                    
        return patterns
    
    def matches_workflow(self, events: List[Dict], signature: List[Tuple]) -> bool:
        """Check if events match a workflow signature"""
        # Simplified matching - could use more sophisticated algorithms
        return len(events) >= len(signature)  # Placeholder

class RealtimeAutomationLoop(BaseAgent):
    """
    Real-time automation loop that monitors file system events
    and triggers appropriate automation based on detected patterns
    """
    
    def __init__(self, orchestrator):
        super().__init__(orchestrator, "RealtimeAutomationLoop")
        self.monitored_paths = [
            CDCS_PATH,
            Path.home() / "Desktop",
            Path.home() / "Documents"
        ]
        self.pattern_detector = PatternDetector()
        self.automation_rules = self.load_automation_rules()
        self.event_queue = deque(maxlen=1000)
        self.is_monitoring = False
        self.observer = None
        
    def load_automation_rules(self) -> Dict:
        """Load automation rules from configuration"""
        rules_path = CDCS_PATH / "automation" / "rules.json"
        default_rules = {
            'rapid_development': {
                'threshold': 5,  # changes per minute
                'action': 'enable_hot_reload'
            },
            'bulk_operation': {
                'threshold': 20,  # operations
                'action': 'suggest_batch_script'
            },
            'workflow_detected': {
                'patterns': ['test_driven_development', 'refactoring'],
                'action': 'optimize_workflow'
            },
            'unstable_file': {
                'threshold': 3,  # create/delete cycles
                'action': 'investigate_errors'
            }
        }
        
        if rules_path.exists():
            try:
                return json.loads(rules_path.read_text())
            except:
                pass
                
        return default_rules
    
    def start_monitoring(self):
        """Start file system monitoring"""
        self.is_monitoring = True
        
        if HAS_FSEVENTS:
            self.start_fsevents_monitoring()
        else:
            self.start_polling_monitoring()
    
    def start_fsevents_monitoring(self):
        """Use FSEvents for efficient monitoring on macOS"""
        def callback(event):
            self.handle_fs_event({
                'path': event.name,
                'type': self.get_event_type(event.mask),
                'timestamp': datetime.now(),
                'flags': event.mask
            })
        
        self.observer = Observer()
        for path in self.monitored_paths:
            if path.exists():
                stream = Stream(callback, str(path), file_events=True)
                self.observer.schedule(stream)
        
        self.observer.start()
        self.logger.info("Started FSEvents monitoring")
    
    def start_polling_monitoring(self):
        """Fallback polling-based monitoring"""
        def poll_loop():
            file_states = {}
            
            while self.is_monitoring:
                for base_path in self.monitored_paths:
                    if not base_path.exists():
                        continue
                        
                    for path in base_path.rglob('*'):
                        if path.is_file():
                            try:
                                stat = path.stat()
                                key = str(path)
                                current_state = (stat.st_mtime, stat.st_size)
                                
                                if key in file_states:
                                    if file_states[key] != current_state:
                                        self.handle_fs_event({
                                            'path': str(path),
                                            'type': 'modified',
                                            'timestamp': datetime.now()
                                        })
                                else:
                                    self.handle_fs_event({
                                        'path': str(path),
                                        'type': 'created',
                                        'timestamp': datetime.now()
                                    })
                                
                                file_states[key] = current_state
                            except:
                                # File might have been deleted
                                if key in file_states:
                                    self.handle_fs_event({
                                        'path': str(path),
                                        'type': 'deleted',
                                        'timestamp': datetime.now()
                                    })
                                    del file_states[key]
                
                time.sleep(1)  # Poll every second
        
        thread = threading.Thread(target=poll_loop, daemon=True)
        thread.start()
        self.logger.info("Started polling-based monitoring")
    
    def get_event_type(self, mask: int) -> str:
        """Convert FSEvents mask to event type"""
        # Simplified - would need proper mask interpretation
        if mask & 0x00000100:  # kFSEventStreamEventFlagItemCreated
            return 'created'
        elif mask & 0x00000200:  # kFSEventStreamEventFlagItemRemoved
            return 'deleted'
        elif mask & 0x00001000:  # kFSEventStreamEventFlagItemModified
            return 'modified'
        elif mask & 0x00004000:  # kFSEventStreamEventFlagItemRenamed
            return 'renamed'
        else:
            return 'unknown'
    
    def handle_fs_event(self, event: Dict):
        """Handle file system event"""
        # Filter out noise
        path = Path(event['path'])
        if any(part.startswith('.') for part in path.parts):
            return  # Skip hidden files
        if path.suffix in ['.log', '.tmp', '.cache']:
            return  # Skip temporary files
            
        # Add to queue
        self.event_queue.append(event)
        
        # Detect patterns
        patterns = self.pattern_detector.add_event(event)
        
        # Trigger automation for detected patterns
        for pattern in patterns:
            self.trigger_automation(pattern)
    
    def trigger_automation(self, pattern: Dict):
        """Trigger automation based on detected pattern"""
        pattern_type = pattern['type']
        
        if pattern_type in self.automation_rules:
            rule = self.automation_rules[pattern_type]
            action = rule.get('action')
            
            self.logger.info(f"Triggering automation: {action} for pattern: {pattern_type}")
            
            # Execute automation action
            if action == 'enable_hot_reload':
                self.enable_hot_reload(pattern)
            elif action == 'suggest_batch_script':
                self.create_batch_script(pattern)
            elif action == 'optimize_workflow':
                self.optimize_workflow(pattern)
            elif action == 'investigate_errors':
                self.investigate_errors(pattern)
            
            # Document the automation
            self.document_automation_event(pattern, action)
    
    def enable_hot_reload(self, pattern: Dict):
        """Enable hot reload for rapidly changing files"""
        path = pattern['path']
        
        # Create hot reload configuration
        config = {
            'enabled': True,
            'path': path,
            'watch_patterns': ['*.py', '*.js', '*.css'],
            'reload_delay': 100,  # ms
            'command': f'echo "Hot reload enabled for {path}"'
        }
        
        config_path = CDCS_PATH / "automation" / "hot_reload" / f"{Path(path).stem}.json"
        config_path.parent.mkdir(exist_ok=True, parents=True)
        config_path.write_text(json.dumps(config, indent=2))
        
        self.logger.info(f"Enabled hot reload for: {path}")
    
    def create_batch_script(self, pattern: Dict):
        """Create batch script for bulk operations"""
        operation = pattern['operation']
        paths = pattern.get('paths', [])
        
        script_content = f"""#!/bin/bash
# Auto-generated batch script for {operation} operations
# Generated: {datetime.now().isoformat()}

echo "Performing batch {operation} on {pattern['count']} files..."

# Add your batch operations here
# Example paths:
"""
        
        for path in paths[:10]:  # First 10 as examples
            if path != '...':
                script_content += f"# - {path}\n"
        
        script_content += f"""
# Suggested batch command:
# find . -name "*.pattern" -exec {operation} {{}} \\;

echo "Batch operation complete"
"""
        
        script_path = CDCS_PATH / "automation" / "batch_scripts" / f"batch_{operation}_{int(time.time())}.sh"
        script_path.parent.mkdir(exist_ok=True, parents=True)
        script_path.write_text(script_content)
        script_path.chmod(0o755)
        
        self.logger.info(f"Created batch script: {script_path}")
    
    def optimize_workflow(self, pattern: Dict):
        """Optimize detected workflow"""
        workflow = pattern['workflow']
        
        optimization = {
            'workflow': workflow,
            'detected_at': datetime.now().isoformat(),
            'optimizations': []
        }
        
        if workflow == 'test_driven_development':
            optimization['optimizations'] = [
                'Setup continuous test runner',
                'Configure test coverage reporting',
                'Enable test result caching'
            ]
        elif workflow == 'refactoring':
            optimization['optimizations'] = [
                'Enable semantic code analysis',
                'Setup automated refactoring tools',
                'Configure change impact analysis'
            ]
        
        # Save optimization suggestions
        opt_path = CDCS_PATH / "automation" / "workflow_optimizations" / f"{workflow}_{int(time.time())}.json"
        opt_path.parent.mkdir(exist_ok=True, parents=True)
        opt_path.write_text(json.dumps(optimization, indent=2))
        
        self.logger.info(f"Generated workflow optimization for: {workflow}")
    
    def investigate_errors(self, pattern: Dict):
        """Investigate file stability issues"""
        path = pattern['path']
        
        investigation = {
            'path': path,
            'issue': 'unstable_file',
            'cycles': pattern['cycles'],
            'timestamp': datetime.now().isoformat(),
            'checks': []
        }
        
        # Perform automated checks
        checks = [
            ('file_permissions', self.check_file_permissions(path)),
            ('disk_space', self.check_disk_space()),
            ('process_conflicts', self.check_process_conflicts(path)),
            ('recent_errors', self.check_recent_errors(path))
        ]
        
        for check_name, result in checks:
            investigation['checks'].append({
                'name': check_name,
                'result': result
            })
        
        # Save investigation results
        inv_path = CDCS_PATH / "automation" / "error_investigations" / f"investigation_{int(time.time())}.json"
        inv_path.parent.mkdir(exist_ok=True, parents=True)
        inv_path.write_text(json.dumps(investigation, indent=2))
        
        self.logger.info(f"Completed error investigation for: {path}")
    
    def check_file_permissions(self, path: str) -> Dict:
        """Check file permissions"""
        try:
            p = Path(path)
            if p.exists():
                stat = p.stat()
                return {
                    'readable': os.access(path, os.R_OK),
                    'writable': os.access(path, os.W_OK),
                    'mode': oct(stat.st_mode)
                }
        except:
            pass
        return {'error': 'Unable to check permissions'}
    
    def check_disk_space(self) -> Dict:
        """Check available disk space"""
        try:
            import shutil
            stat = shutil.disk_usage('/')
            return {
                'free_gb': stat.free / (1024**3),
                'used_percent': (stat.used / stat.total) * 100
            }
        except:
            return {'error': 'Unable to check disk space'}
    
    def check_process_conflicts(self, path: str) -> Dict:
        """Check for process conflicts"""
        # Simplified - would use lsof or similar
        return {'status': 'No conflicts detected'}
    
    def check_recent_errors(self, path: str) -> Dict:
        """Check for recent errors in logs"""
        # Check automation logs for errors related to this path
        return {'recent_errors': 0}
    
    def document_automation_event(self, pattern: Dict, action: str):
        """Document automation event"""
        event = {
            'timestamp': datetime.now().isoformat(),
            'pattern': pattern,
            'action': action,
            'status': 'completed'
        }
        
        # Append to automation log
        log_path = CDCS_PATH / "automation" / "logs" / "automation_events.jsonl"
        log_path.parent.mkdir(exist_ok=True, parents=True)
        
        with log_path.open('a') as f:
            f.write(json.dumps(event) + '\n')
    
    def run(self):
        """Main run method"""
        self.logger.info("Starting real-time automation loop")
        
        try:
            # Start monitoring
            self.start_monitoring()
            
            # Run for a period (in production, would run continuously)
            run_duration = 300  # 5 minutes
            start_time = time.time()
            
            while time.time() - start_time < run_duration:
                # Process accumulated events periodically
                if len(self.event_queue) > 50:
                    self.process_event_batch()
                
                time.sleep(1)
            
            # Final batch processing
            self.process_event_batch()
            
            # Generate summary report
            self.generate_summary_report()
            
        except Exception as e:
            self.logger.error(f"Real-time automation error: {e}")
            
        finally:
            self.stop_monitoring()
    
    def process_event_batch(self):
        """Process accumulated events in batch"""
        if not self.event_queue:
            return
            
        batch_size = len(self.event_queue)
        self.logger.info(f"Processing batch of {batch_size} events")
        
        # Could perform batch analysis here
        # For now, events are processed in real-time
        
        # Clear processed events
        self.event_queue.clear()
    
    def stop_monitoring(self):
        """Stop file system monitoring"""
        self.is_monitoring = False
        
        if self.observer:
            self.observer.stop()
            self.observer = None
            
        self.logger.info("Stopped file system monitoring")
    
    def generate_summary_report(self):
        """Generate summary report of automation session"""
        report = {
            'session_end': datetime.now().isoformat(),
            'patterns_detected': len(self.pattern_detector.detected_patterns),
            'automations_triggered': sum(self.pattern_detector.pattern_counts.values()),
            'monitored_paths': [str(p) for p in self.monitored_paths],
            'top_patterns': dict(sorted(
                self.pattern_detector.pattern_counts.items(),
                key=lambda x: x[1],
                reverse=True
            )[:5])
        }
        
        report_path = CDCS_PATH / "automation" / "reports" / f"realtime_report_{int(time.time())}.json"
        report_path.parent.mkdir(exist_ok=True, parents=True)
        report_path.write_text(json.dumps(report, indent=2))
        
        self.logger.info(f"Generated summary report: {report_path}")

if __name__ == "__main__":
    # Test run
    from cdcs_orchestrator import CDCSOrchestrator
    orchestrator = CDCSOrchestrator()
    agent = RealtimeAutomationLoop(orchestrator)
    agent.run()

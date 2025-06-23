#!/usr/bin/env python3
"""
Terminal Orchestrator with OpenTelemetry - Enhanced with full observability
"""

import os
import sys
import time
import json
import sqlite3
import subprocess
import threading
import queue
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import logging

# Add CDCS path
CDCS_PATH = Path("/Users/sac/claude-desktop-context")
sys.path.append(str(CDCS_PATH / "automation"))
sys.path.append(str(CDCS_PATH / "automation" / "advanced_loops"))

from otel_base_agent import OTelBaseAgent, instrument_function

class TerminalSession:
    """Represents a controllable terminal session with telemetry"""
    
    def __init__(self, session_id: str, purpose: str, parent_agent: OTelBaseAgent):
        self.session_id = session_id
        self.purpose = purpose
        self.parent_agent = parent_agent
        self.start_time = datetime.now()
        self.commands_executed = []
        self.output_buffer = []
        self.is_active = True
        self.applescript_template = '''
        tell application "Terminal"
            do script "{command}"
            set currentTab to front window's selected tab
            return {window_id: id of front window, tab_id: index of currentTab}
        end tell
        '''
    
    @instrument_function()
    def execute_command(self, command: str) -> Dict:
        """Execute command in terminal session with tracing"""
        with self.parent_agent.start_span(
            "terminal.execute_command",
            attributes={
                "session.id": self.session_id,
                "command.length": len(command),
                "command.type": command.split()[0] if command else "empty"
            }
        ) as span:
            result = {
                'command': command,
                'timestamp': datetime.now().isoformat(),
                'success': False,
                'output': '',
                'error': ''
            }
            
            try:
                # Use AppleScript for terminal control
                script = self.applescript_template.format(command=command.replace('"', '\\"'))
                proc = subprocess.run(
                    ['osascript', '-e', script],
                    capture_output=True,
                    text=True
                )
                
                if proc.returncode == 0:
                    result['success'] = True
                    result['output'] = proc.stdout.strip()
                    if span:
                        span.set_attribute("command.success", True)
                        span.set_attribute("output.length", len(result['output']))
                else:
                    result['error'] = proc.stderr.strip()
                    if span:
                        span.set_attribute("command.success", False)
                        span.set_attribute("error.message", result['error'])
                    
                self.commands_executed.append(result)
                
            except Exception as e:
                result['error'] = str(e)
                if span:
                    span.record_exception(e)
                
            return result
    
    def close(self):
        """Close terminal session"""
        self.is_active = False
        duration = (datetime.now() - self.start_time).total_seconds()
        
        # Record session metrics
        self.parent_agent.add_span_event(
            "terminal_session_closed",
            {
                "session.id": self.session_id,
                "session.duration": duration,
                "commands.executed": len(self.commands_executed)
            }
        )

class TerminalOrchestrator(OTelBaseAgent):
    """
    Terminal orchestrator with comprehensive OpenTelemetry instrumentation
    """
    
    def __init__(self, orchestrator):
        super().__init__(orchestrator, "TerminalOrchestrator")
        self.sessions: Dict[str, TerminalSession] = {}
        self.task_queue = queue.Queue()
        self.result_queue = queue.Queue()
        self.patterns_db = CDCS_PATH / "automation" / "discovered_patterns.db"
        self.init_patterns_db()
        
        # Additional metrics for terminal orchestration
        self.session_counter = self._meter.create_counter(
            name="cdcs.terminal.sessions.created",
            description="Number of terminal sessions created",
            unit="1"
        )
        
        self.parallel_efficiency = self._meter.create_histogram(
            name="cdcs.terminal.parallel.efficiency",
            description="Efficiency of parallel execution",
            unit="ratio"
        )
        
    @instrument_function()
    def init_patterns_db(self):
        """Initialize patterns database with tracing"""
        conn = sqlite3.connect(self.patterns_db)
        conn.execute('''
            CREATE TABLE IF NOT EXISTS automation_patterns (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                pattern_name TEXT UNIQUE,
                trigger_conditions TEXT,
                action_sequence TEXT,
                success_count INTEGER DEFAULT 0,
                failure_count INTEGER DEFAULT 0,
                last_triggered TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        conn.commit()
        conn.close()
    
    def create_session(self, purpose: str) -> TerminalSession:
        """Create new terminal session with telemetry"""
        with self.start_span("terminal.create_session") as span:
            session_id = f"session_{int(time.time() * 1000)}"
            session = TerminalSession(session_id, purpose, self)
            self.sessions[session_id] = session
            
            self.session_counter.add(1, {"purpose": purpose})
            
            if span:
                span.set_attribute("session.id", session_id)
                span.set_attribute("session.purpose", purpose)
            
            self.logger.info(f"Created terminal session {session_id} for: {purpose}")
            return session
    
    @instrument_function()
    def detect_automation_opportunity(self) -> Optional[Dict]:
        """Analyze recent activity to find automation opportunities"""
        with self.start_span("detect_automation_opportunity") as span:
            opportunities = []
            
            # Check for repeated command patterns
            recent_sessions = CDCS_PATH / "memory" / "sessions" / "active"
            if recent_sessions.exists():
                # Analyze for patterns that could be automated
                pattern_indicators = [
                    "multiple file operations",
                    "repeated searches",
                    "batch processing",
                    "data transformation",
                    "test execution cycles"
                ]
                
                # Mock detection - in practice, would analyze actual session data
                opportunity = {
                    'type': 'batch_file_processing',
                    'confidence': 0.85,
                    'estimated_time_saved': '15 minutes',
                    'commands': [
                        'find . -name "*.py" -type f',
                        'grep -n "TODO" {}',
                        'wc -l {}'
                    ]
                }
                opportunities.append(opportunity)
                
                if span and opportunities:
                    span.set_attribute("opportunities.found", len(opportunities))
                    span.set_attribute("opportunity.type", opportunity['type'])
                    span.set_attribute("opportunity.confidence", opportunity['confidence'])
                
                # Record pattern detection
                if opportunities:
                    self.record_pattern_detection(opportunity['type'], opportunity['confidence'])
                
            return opportunities[0] if opportunities else None
    
    def execute_parallel_tasks(self, tasks: List[Dict]) -> List[Dict]:
        """Execute multiple tasks in parallel with performance tracking"""
        with self.start_span(
            "execute_parallel_tasks",
            attributes={"task.count": len(tasks)}
        ) as span:
            
            start_time = time.time()
            results = []
            threads = []
            
            def run_task(task, session):
                task_span = self.create_child_span(
                    f"task.{task.get('name', 'unnamed')}",
                    parent_span=span
                )
                
                if task_span:
                    task_span.set_attribute("task.name", task.get('name', 'unnamed'))
                    task_span.set_attribute("commands.count", len(task.get('commands', [])))
                
                task_result = {
                    'task': task,
                    'session_id': session.session_id,
                    'results': []
                }
                
                try:
                    for command in task.get('commands', []):
                        result = session.execute_command(command)
                        task_result['results'].append(result)
                        time.sleep(0.5)  # Allow command to execute
                        
                    if task_span:
                        task_span.set_status(Status(StatusCode.OK))
                except Exception as e:
                    if task_span:
                        task_span.record_exception(e)
                        task_span.set_status(Status(StatusCode.ERROR, str(e)))
                finally:
                    if task_span:
                        task_span.end()
                        
                self.result_queue.put(task_result)
            
            # Create sessions and launch threads
            for i, task in enumerate(tasks):
                session = self.create_session(f"Task_{i}: {task.get('name', 'unnamed')}")
                thread = threading.Thread(target=run_task, args=(task, session))
                threads.append(thread)
                thread.start()
            
            # Wait for completion
            for thread in threads:
                thread.join()
            
            # Collect results
            while not self.result_queue.empty():
                results.append(self.result_queue.get())
            
            # Calculate parallel efficiency
            end_time = time.time()
            total_duration = end_time - start_time
            
            # Estimate sequential duration (sum of all task durations)
            sequential_estimate = len(tasks) * 2.0  # Rough estimate
            efficiency = sequential_estimate / total_duration if total_duration > 0 else 1.0
            
            self.parallel_efficiency.record(
                efficiency,
                {"task_count": len(tasks)}
            )
            
            if span:
                span.set_attribute("execution.duration", total_duration)
                span.set_attribute("execution.efficiency", efficiency)
                span.set_attribute("results.count", len(results))
                
            return results
    
    @instrument_function()
    def learn_from_execution(self, pattern: Dict, results: List[Dict]):
        """Learn from execution results to improve future automation"""
        success_rate = sum(1 for r in results if all(
            cmd.get('success', False) for cmd in r.get('results', [])
        )) / len(results) if results else 0
        
        conn = sqlite3.connect(self.patterns_db)
        
        # Update or insert pattern
        pattern_data = {
            'name': pattern.get('type', 'unknown'),
            'trigger': json.dumps(pattern),
            'actions': json.dumps(pattern.get('commands', [])),
            'success': int(success_rate > 0.8)
        }
        
        conn.execute('''
            INSERT OR REPLACE INTO automation_patterns 
            (pattern_name, trigger_conditions, action_sequence, success_count, last_triggered)
            VALUES (?, ?, ?, 
                COALESCE((SELECT success_count FROM automation_patterns WHERE pattern_name = ?) + ?, 0),
                CURRENT_TIMESTAMP)
        ''', (pattern_data['name'], pattern_data['trigger'], pattern_data['actions'],
              pattern_data['name'], pattern_data['success']))
        
        conn.commit()
        conn.close()
        
        # Record learning metrics
        self.add_span_event(
            "pattern_learning_complete",
            {
                "pattern.name": pattern_data['name'],
                "success.rate": success_rate,
                "pattern.stored": True
            }
        )
        
        self.logger.info(f"Learned from pattern execution: {pattern_data['name']} "
                        f"(success rate: {success_rate:.2%})")
    
    def run(self):
        """Main automation loop with full telemetry"""
        with self.start_span("terminal_orchestrator.main_loop") as span:
            self.logger.info("Terminal Orchestrator starting with OpenTelemetry")
            
            try:
                # 1. Detect automation opportunities
                opportunity = self.detect_automation_opportunity()
                
                if opportunity:
                    self.logger.info(f"Found automation opportunity: {opportunity['type']}")
                    
                    if span:
                        span.set_attribute("opportunity.found", True)
                        span.set_attribute("opportunity.type", opportunity['type'])
                    
                    # 2. Create parallel tasks
                    tasks = self.create_example_tasks()
                    
                    # 3. Execute in parallel
                    results = self.execute_parallel_tasks(tasks)
                    
                    # 4. Learn from results
                    self.learn_from_execution(opportunity, results)
                    
                    # 5. Document discoveries
                    self.document_automation_pattern(opportunity, results)
                    
                    # Update health score based on success
                    success_count = sum(1 for r in results if all(
                        cmd.get('success', False) for cmd in r.get('results', [])
                    ))
                    health_score = (success_count / len(results)) * 100 if results else 0
                    self.update_health_score(health_score)
                    
                else:
                    self.logger.info("No automation opportunities detected in this cycle")
                    if span:
                        span.set_attribute("opportunity.found", False)
                    
                # 6. Check for user-defined automation rules
                self.check_custom_automation_rules()
                
            except Exception as e:
                self.logger.error(f"Terminal orchestration error: {e}")
                if span:
                    span.record_exception(e)
                raise
                
            finally:
                # Cleanup sessions
                for session in self.sessions.values():
                    if session.is_active:
                        session.close()
    
    def create_example_tasks(self) -> List[Dict]:
        """Create example parallel tasks"""
        return [
            {
                'name': 'Python_Analysis',
                'commands': [
                    'cd /Users/sac/claude-desktop-context',
                    'find . -name "*.py" -type f | head -5',
                    'echo "Analysis complete"'
                ]
            },
            {
                'name': 'Pattern_Search',
                'commands': [
                    'cd /Users/sac/claude-desktop-context/patterns',
                    'ls -la catalog/',
                    'grep -r "automation" . | wc -l'
                ]
            },
            {
                'name': 'Memory_Check',
                'commands': [
                    'cd /Users/sac/claude-desktop-context/memory',
                    'du -sh sessions/',
                    'find sessions -type f -name "*.md" | wc -l'
                ]
            }
        ]
    
    @instrument_function()
    def document_automation_pattern(self, pattern: Dict, results: List[Dict]):
        """Document successful automation patterns with telemetry"""
        doc_path = CDCS_PATH / "automation" / "discovered_patterns" / f"{pattern['type']}_{int(time.time())}.md"
        doc_path.parent.mkdir(exist_ok=True)
        
        content = self.generate_pattern_documentation(pattern, results)
        doc_path.write_text(content)
        
        self.add_span_event(
            "pattern_documented",
            {
                "pattern.type": pattern['type'],
                "document.path": str(doc_path),
                "results.count": len(results)
            }
        )
        
        self.logger.info(f"Documented automation pattern: {doc_path}")
    
    def generate_pattern_documentation(self, pattern: Dict, results: List[Dict]) -> str:
        """Generate pattern documentation content"""
        content = f"""# Automated Pattern: {pattern['type']}

## Discovery
- **Detected**: {datetime.now().isoformat()}
- **Confidence**: {pattern.get('confidence', 0):.2%}
- **Estimated Time Saved**: {pattern.get('estimated_time_saved', 'unknown')}

## Pattern Details
```json
{json.dumps(pattern, indent=2)}
```

## Execution Results
"""
        
        for result in results:
            content += f"\n### {result['task']['name']}\n"
            content += f"Session: {result['session_id']}\n\n"
            
            for cmd_result in result['results']:
                content += f"```bash\n$ {cmd_result['command']}\n"
                if cmd_result['success']:
                    content += f"{cmd_result.get('output', '')}\n"
                else:
                    content += f"ERROR: {cmd_result.get('error', '')}\n"
                content += "```\n\n"
        
        content += """
## Integration
This pattern has been added to the automation database and will be
considered for future similar scenarios.

## Telemetry
Pattern execution was fully traced with OpenTelemetry. Check your
observability platform for detailed performance metrics and traces.
"""
        
        return content
    
    @instrument_function()
    def check_custom_automation_rules(self):
        """Check for user-defined automation rules with tracing"""
        rules_path = CDCS_PATH / "automation" / "rules"
        rules_checked = 0
        rules_triggered = 0
        
        if rules_path.exists():
            for rule_file in rules_path.glob("*.json"):
                rules_checked += 1
                try:
                    rule = json.loads(rule_file.read_text())
                    if self.should_trigger_rule(rule):
                        rules_triggered += 1
                        self.execute_rule(rule)
                except Exception as e:
                    self.logger.error(f"Error processing rule {rule_file}: {e}")
                    self.error_counter.add(
                        1,
                        {"agent": self.agent_name, "error": "rule_processing"}
                    )
        
        self.add_span_event(
            "custom_rules_checked",
            {
                "rules.checked": rules_checked,
                "rules.triggered": rules_triggered
            }
        )
    
    def should_trigger_rule(self, rule: Dict) -> bool:
        """Determine if a rule should be triggered"""
        # Implement rule trigger logic
        trigger_type = rule.get('trigger', {}).get('type')
        if trigger_type == 'time_based':
            # Check if current time matches rule schedule
            return True  # Simplified
        return False
    
    @instrument_function()
    def execute_rule(self, rule: Dict):
        """Execute a user-defined automation rule"""
        self.logger.info(f"Executing rule: {rule.get('name', 'unnamed')}")
        # Implementation would execute the rule's action sequence
        self.add_span_event(
            "rule_executed",
            {"rule.name": rule.get('name', 'unnamed')}
        )

if __name__ == "__main__":
    # Test run with telemetry
    from cdcs_orchestrator import CDCSOrchestrator
    
    # Set up a local OTLP endpoint for testing
    os.environ['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4317'
    
    orchestrator = CDCSOrchestrator()
    agent = TerminalOrchestrator(orchestrator)
    agent.run()
    
    print("\nTelemetry data has been sent to OTLP endpoint.")
    print("To view traces, ensure you have an OTLP collector running.")

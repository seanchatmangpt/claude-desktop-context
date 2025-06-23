#!/usr/bin/env python3
"""
Evolution Hunter Agent - Identifies opportunities for system evolution
Uses ollama/qwen3 to discover improvement possibilities
"""

import json
from pathlib import Path
from typing import Dict, List, Tuple
import datetime
import numpy as np

class EvolutionHunter:
    def __init__(self, orchestrator):
        self.orchestrator = orchestrator
        self.task_description = "Hunting for evolution opportunities"
        self.evolution_path = Path("/Users/sac/claude-desktop-context/evolution")
        self.mutations_path = self.evolution_path / "mutations"
        self.mutations_path.mkdir(parents=True, exist_ok=True)
        
    def analyze_performance_bottlenecks(self) -> List[Dict]:
        """Identify system performance bottlenecks"""
        
        bottlenecks = []
        
        # Analyze recent automation runs
        import sqlite3
        conn = sqlite3.connect(self.orchestrator.db_path)
        
        # Find slow operations
        slow_ops = conn.execute("""
            SELECT agent, task, AVG(tokens_processed) as avg_tokens,
                   AVG(CAST(json_extract(metadata, '$.execution_time') AS REAL)) as avg_time
            FROM automation_runs
            WHERE timestamp > datetime('now', '-7 days')
            GROUP BY agent, task
            HAVING avg_time > 5.0
            ORDER BY avg_time DESC
        """).fetchall()
        
        for agent, task, avg_tokens, avg_time in slow_ops:
            bottlenecks.append({
                'type': 'performance',
                'component': agent,
                'task': task,
                'current_performance': avg_time,
                'tokens_processed': avg_tokens,
                'severity': min(avg_time / 10.0, 1.0)  # Normalize to 0-1
            })
            
        # Analyze memory usage patterns
        memory_patterns = conn.execute("""
            SELECT COUNT(*) as session_count,
                   AVG(CAST(json_extract(metadata, '$.lines') AS INTEGER)) as avg_lines
            FROM automation_runs
            WHERE task LIKE '%memory%'
            AND timestamp > datetime('now', '-7 days')
        """).fetchone()
        
        if memory_patterns and memory_patterns[1] > 5000:
            bottlenecks.append({
                'type': 'memory',
                'component': 'session_management',
                'current_performance': memory_patterns[1],
                'severity': min(memory_patterns[1] / 10000, 1.0)
            })
            
        conn.close()
        return bottlenecks
        
    def identify_repetitive_operations(self, sessions: List[Dict]) -> List[Dict]:
        """Find operations that could be automated"""
        
        repetitive_ops = []
        
        # Use ollama to analyze for repetitive patterns
        system_prompt = """Analyze these CDCS sessions for repetitive operations that could be automated.
        Look for:
        1. Commands or sequences run multiple times
        2. Similar file operations with different parameters
        3. Pattern applications that could be templated
        4. Manual processes that follow consistent steps
        
        Output JSON:
        {
            "operations": [
                {
                    "name": "operation name",
                    "frequency": number of occurrences,
                    "pattern": "the repetitive pattern",
                    "automation_potential": 0.0-1.0,
                    "proposed_solution": "how to automate"
                }
            ]
        }
        """
        
        # Analyze recent sessions
        session_sample = '\n\n'.join([s['content'][:1000] for s in sessions[:5]])
        prompt = f"Find repetitive operations in:\n{session_sample}"
        
        response = self.orchestrator.ollama_query(prompt, system_prompt)
        
        try:
            ops = json.loads(response).get('operations', [])
            for op in ops:
                if op['frequency'] > 2:  # Threshold for repetition
                    repetitive_ops.append({
                        'type': 'repetitive_operation',
                        'operation': op['name'],
                        'frequency': op['frequency'],
                        'automation_potential': op['automation_potential'],
                        'solution': op['proposed_solution'],
                        'priority': op['frequency'] * op['automation_potential']
                    })
        except:
            pass
            
        return repetitive_ops
        
    def discover_capability_combinations(self) -> List[Dict]:
        """Find unexplored combinations of existing capabilities"""
        
        # Get current patterns
        patterns_path = Path("/Users/sac/claude-desktop-context/patterns/catalog")
        existing_patterns = []
        
        if patterns_path.exists():
            for pattern_file in patterns_path.rglob("*.md"):
                existing_patterns.append(pattern_file.stem)
                
        # Use ollama to suggest combinations
        system_prompt = """Given these existing CDCS patterns, suggest novel combinations that could create emergent capabilities.
        Think about:
        1. Patterns that could work in sequence
        2. Patterns that could work in parallel
        3. Patterns that could be composed into meta-patterns
        4. Cross-domain pattern applications
        
        Output JSON:
        {
            "combinations": [
                {
                    "name": "combination name",
                    "patterns": ["pattern1", "pattern2"],
                    "description": "what emerges from combination",
                    "novelty": 0.0-1.0,
                    "utility": 0.0-1.0,
                    "implementation": "how to combine"
                }
            ]
        }
        """
        
        prompt = f"Suggest combinations for patterns: {existing_patterns[:20]}"
        response = self.orchestrator.ollama_query(prompt, system_prompt)
        
        combinations = []
        try:
            combos = json.loads(response).get('combinations', [])
            for combo in combos:
                combinations.append({
                    'type': 'capability_combination',
                    'name': combo['name'],
                    'components': combo['patterns'],
                    'emergence_potential': combo['novelty'] * combo['utility'],
                    'description': combo['description'],
                    'implementation': combo['implementation']
                })
        except:
            pass
            
        return combinations
        
    def analyze_failure_patterns(self) -> List[Dict]:
        """Learn from failures to identify evolution needs"""
        
        failures = []
        
        # Look for error patterns in logs
        logs_path = self.orchestrator.automation_path / "logs"
        if logs_path.exists():
            for log_file in logs_path.glob("*.log"):
                content = log_file.read_text()
                
                # Count error types
                import re
                errors = re.findall(r'ERROR:.*?:(.*?)(?:\n|$)', content)
                timeouts = len(re.findall(r'timeout|timed out', content, re.I))
                memory_errors = len(re.findall(r'memory|overflow|too large', content, re.I))
                
                if errors or timeouts or memory_errors:
                    failures.append({
                        'type': 'failure_pattern',
                        'source': log_file.name,
                        'error_count': len(errors),
                        'timeout_count': timeouts,
                        'memory_issues': memory_errors,
                        'severity': min((len(errors) + timeouts + memory_errors) / 10, 1.0)
                    })
                    
        return failures
        
    def generate_evolution_hypothesis(self, opportunity: Dict) -> Dict:
        """Generate detailed evolution hypothesis"""
        
        system_prompt = """Generate a detailed evolution hypothesis for CDCS.
        Include:
        1. Specific implementation steps
        2. Expected benefits with metrics
        3. Potential risks and mitigations
        4. Success criteria
        5. Rollback plan
        
        Output JSON:
        {
            "hypothesis": "what will improve",
            "implementation": ["step1", "step2", ...],
            "benefits": {
                "performance": "expected improvement",
                "capability": "new abilities",
                "efficiency": "resource savings"
            },
            "risks": ["risk1", "risk2"],
            "success_criteria": ["criterion1", "criterion2"],
            "rollback": "how to revert if needed"
        }
        """
        
        prompt = f"Generate evolution hypothesis for: {json.dumps(opportunity)}"
        response = self.orchestrator.ollama_query(prompt, system_prompt)
        
        try:
            hypothesis = json.loads(response)
            hypothesis['opportunity'] = opportunity
            hypothesis['confidence'] = self.calculate_hypothesis_confidence(opportunity)
            hypothesis['timestamp'] = datetime.datetime.now().isoformat()
            return hypothesis
        except:
            return {
                'hypothesis': f"Improve {opportunity.get('type', 'system')}",
                'opportunity': opportunity,
                'confidence': 0.5,
                'timestamp': datetime.datetime.now().isoformat()
            }
            
    def calculate_hypothesis_confidence(self, opportunity: Dict) -> float:
        """Calculate confidence in evolution hypothesis"""
        
        base_confidence = 0.5
        
        # Adjust based on opportunity type
        if opportunity.get('type') == 'performance':
            base_confidence += 0.2  # Performance improvements are well-understood
        elif opportunity.get('type') == 'capability_combination':
            base_confidence += 0.1  # Combinations have moderate confidence
        elif opportunity.get('type') == 'failure_pattern':
            base_confidence += 0.15  # Learning from failures is reliable
            
        # Adjust based on severity/priority
        if opportunity.get('severity', 0) > 0.7:
            base_confidence += 0.1
        if opportunity.get('priority', 0) > 0.8:
            base_confidence += 0.1
            
        return min(base_confidence, 0.95)
        
    def test_evolution_hypothesis(self, hypothesis: Dict) -> Dict:
        """Test evolution hypothesis in isolation"""
        
        test_results = {
            'hypothesis': hypothesis['hypothesis'],
            'tested': datetime.datetime.now().isoformat(),
            'results': []
        }
        
        # Create test environment
        test_path = self.mutations_path / "tests" / hypothesis['timestamp'].replace(':', '-')
        test_path.mkdir(parents=True, exist_ok=True)
        
        # Simulate implementation steps
        for i, step in enumerate(hypothesis.get('implementation', [])):
            # Use ollama to evaluate step feasibility
            prompt = f"Evaluate feasibility of: {step}"
            evaluation = self.orchestrator.ollama_query(prompt, 
                "Rate 0-1 feasibility and explain challenges briefly")
            
            test_results['results'].append({
                'step': i,
                'description': step,
                'feasibility': evaluation
            })
            
        # Calculate overall success probability
        test_results['success_probability'] = hypothesis['confidence'] * 0.8
        test_results['recommendation'] = 'implement' if test_results['success_probability'] > 0.6 else 'iterate'
        
        return test_results
        
    def save_evolution_opportunity(self, hypothesis: Dict, test_results: Dict):
        """Save evolution opportunity for implementation"""
        
        opportunity_file = self.mutations_path / f"{hypothesis['timestamp'].replace(':', '-')}_evolution.json"
        
        full_record = {
            'hypothesis': hypothesis,
            'test_results': test_results,
            'status': 'pending',
            'created': datetime.datetime.now().isoformat()
        }
        
        opportunity_file.write_text(json.dumps(full_record, indent=2))
        
        # Update lineage if high confidence
        if test_results['success_probability'] > 0.7:
            lineage_file = self.evolution_path / "lineage.md"
            with open(lineage_file, 'a') as f:
                f.write(f"\n## {hypothesis['timestamp']}: {hypothesis['hypothesis']}\n")
                f.write(f"- Confidence: {hypothesis['confidence']:.2f}\n")
                f.write(f"- Success probability: {test_results['success_probability']:.2f}\n")
                f.write(f"- Type: {hypothesis['opportunity']['type']}\n")
                f.write(f"- Status: Pending implementation\n")
                
    def run(self) -> Dict:
        """Execute evolution hunting"""
        metrics = {
            'tokens_processed': 0,
            'opportunities_found': 0,
            'hypotheses_generated': 0,
            'evolution_score': 0.0,
            'metadata': {}
        }
        
        all_opportunities = []
        
        # 1. Analyze performance bottlenecks
        bottlenecks = self.analyze_performance_bottlenecks()
        all_opportunities.extend(bottlenecks)
        
        # 2. Find repetitive operations
        sessions = self.orchestrator.get_recent_sessions(48)
        if sessions:
            repetitive = self.identify_repetitive_operations(sessions)
            all_opportunities.extend(repetitive)
            metrics['tokens_processed'] += sum(len(s['content']) // 4 for s in sessions[:5])
            
        # 3. Discover capability combinations
        combinations = self.discover_capability_combinations()
        all_opportunities.extend(combinations)
        
        # 4. Analyze failure patterns
        failures = self.analyze_failure_patterns()
        all_opportunities.extend(failures)
        
        metrics['opportunities_found'] = len(all_opportunities)
        
        # Generate hypotheses for top opportunities
        all_opportunities.sort(key=lambda x: x.get('priority', x.get('severity', 0.5)), reverse=True)
        
        hypotheses_tested = []
        for opportunity in all_opportunities[:3]:  # Top 3
            hypothesis = self.generate_evolution_hypothesis(opportunity)
            test_results = self.test_evolution_hypothesis(hypothesis)
            
            self.save_evolution_opportunity(hypothesis, test_results)
            
            hypotheses_tested.append({
                'hypothesis': hypothesis['hypothesis'],
                'confidence': hypothesis['confidence'],
                'success_probability': test_results['success_probability']
            })
            
            metrics['hypotheses_generated'] += 1
            
        # Calculate evolution score
        if hypotheses_tested:
            metrics['evolution_score'] = np.mean([
                h['success_probability'] for h in hypotheses_tested
            ])
            
        metrics['metadata'] = {
            'bottlenecks_found': len(bottlenecks),
            'repetitive_ops': len([o for o in all_opportunities if o['type'] == 'repetitive_operation']),
            'combinations_suggested': len(combinations),
            'failures_analyzed': len(failures),
            'top_opportunities': [
                {
                    'type': o['type'],
                    'priority': o.get('priority', o.get('severity', 0.5))
                }
                for o in all_opportunities[:5]
            ]
        }
        
        return metrics

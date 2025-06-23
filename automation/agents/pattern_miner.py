#!/usr/bin/env python3
"""
Pattern Miner Agent - Discovers recurring patterns in CDCS sessions
Uses ollama/qwen3 for intelligent pattern recognition
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Tuple
import hashlib
from collections import Counter
import numpy as np

class PatternMiner:
    def __init__(self, orchestrator):
        self.orchestrator = orchestrator
        self.task_description = "Mining patterns from recent sessions"
        self.patterns_path = Path("/Users/sac/claude-desktop-context/patterns/discovered")
        self.patterns_path.mkdir(parents=True, exist_ok=True)
        
    def extract_code_patterns(self, content: str) -> List[Dict]:
        """Extract recurring code patterns"""
        patterns = []
        
        # Find code blocks
        code_blocks = re.findall(r'```[\w]*\n(.*?)\n```', content, re.DOTALL)
        
        # Find function definitions
        function_patterns = []
        for block in code_blocks:
            functions = re.findall(r'def\s+(\w+)\s*\((.*?)\):', block)
            function_patterns.extend(functions)
            
        # Find common imports
        import_patterns = re.findall(r'import\s+(\w+)|from\s+(\w+)\s+import', content)
        
        # Find API calls
        api_patterns = re.findall(r'(\w+)\.(\w+)\((.*?)\)', content)
        
        return {
            'functions': function_patterns,
            'imports': import_patterns,
            'api_calls': api_patterns[:20]  # Limit to prevent overflow
        }
        
    def analyze_interaction_patterns(self, sessions: List[Dict]) -> List[Dict]:
        """Use ollama to identify high-level interaction patterns"""
        
        system_prompt = """You are analyzing Claude Desktop Context System sessions.
        Identify recurring patterns in:
        1. User request types
        2. Solution approaches
        3. Tool usage sequences
        4. Knowledge building patterns
        5. Evolution opportunities
        
        Output JSON with structure:
        {
            "patterns": [
                {
                    "name": "pattern_name",
                    "description": "what it does",
                    "occurrences": number,
                    "confidence": 0.0-1.0,
                    "category": "category",
                    "trigger": "when to apply",
                    "implementation": "how to execute"
                }
            ]
        }
        """
        
        # Prepare session summary
        session_summary = "\n\n".join([
            f"Session {s['file']}:\n{s['content'][:1000]}..."
            for s in sessions[:5]  # Analyze last 5 sessions
        ])
        
        prompt = f"Analyze these CDCS sessions for patterns:\n\n{session_summary}"
        
        response = self.orchestrator.ollama_query(prompt, system_prompt)
        
        try:
            return json.loads(response).get('patterns', [])
        except:
            return []
            
    def calculate_pattern_hash(self, pattern: Dict) -> str:
        """Generate unique hash for pattern deduplication"""
        pattern_str = f"{pattern['name']}:{pattern['category']}:{pattern['trigger']}"
        return hashlib.sha256(pattern_str.encode()).hexdigest()[:16]
        
    def save_pattern(self, pattern: Dict) -> bool:
        """Save discovered pattern to database and filesystem"""
        pattern_hash = self.calculate_pattern_hash(pattern)
        
        # Check if pattern already exists
        conn = self.orchestrator.db_path.parent / "cdcs_intelligence.db"
        existing = self.orchestrator.ollama_query(
            f"SELECT id FROM discovered_patterns WHERE pattern_hash = '{pattern_hash}'",
            "Return 'exists' if found, 'new' if not"
        )
        
        if 'new' in existing.lower():
            # Save to database
            import sqlite3
            conn = sqlite3.connect(self.orchestrator.db_path)
            conn.execute("""
                INSERT INTO discovered_patterns 
                (timestamp, pattern_hash, pattern_content, confidence, 
                 information_gain, category)
                VALUES (datetime('now'), ?, ?, ?, ?, ?)
            """, (
                pattern_hash,
                json.dumps(pattern),
                pattern['confidence'],
                self.calculate_information_gain(pattern),
                pattern['category']
            ))
            conn.commit()
            conn.close()
            
            # Save to filesystem
            pattern_file = self.patterns_path / f"{pattern_hash}_{pattern['name']}.json"
            pattern_file.write_text(json.dumps(pattern, indent=2))
            
            return True
        return False
        
    def calculate_information_gain(self, pattern: Dict) -> float:
        """Calculate information gain from pattern discovery"""
        # Based on pattern complexity and utility
        base_gain = len(pattern['implementation']) * 0.01
        confidence_factor = pattern['confidence']
        occurrence_factor = min(pattern['occurrences'] / 10, 1.0)
        
        return base_gain * confidence_factor * occurrence_factor
        
    def mine_emergent_patterns(self, sessions: List[Dict]) -> List[Dict]:
        """Look for emergent behavior patterns"""
        
        prompt = """Analyze for emergent patterns that show:
        1. Capabilities combining in unexpected ways
        2. Novel solutions discovered through exploration
        3. System behaviors beyond original design
        4. Self-organizing properties
        5. Adaptive responses to complexity
        
        Focus on patterns that demonstrate emergence, not just repetition.
        """
        
        emergent_patterns = []
        
        for session in sessions[:3]:
            response = self.orchestrator.ollama_query(
                f"Find emergent patterns in:\n{session['content'][:2000]}",
                prompt
            )
            
            # Extract patterns from response
            if "emergent" in response.lower():
                pattern = {
                    'name': f"emergent_{session['file'][:10]}",
                    'description': response[:200],
                    'occurrences': 1,
                    'confidence': 0.6,
                    'category': 'emergent',
                    'trigger': 'complex_problem',
                    'implementation': response
                }
                emergent_patterns.append(pattern)
                
        return emergent_patterns
        
    def run(self) -> Dict:
        """Execute pattern mining"""
        metrics = {
            'tokens_processed': 0,
            'patterns_found': 0,
            'new_patterns': 0,
            'metadata': {}
        }
        
        # Get recent sessions
        sessions = self.orchestrator.get_recent_sessions(48)  # Last 48 hours
        
        if not sessions:
            return metrics
            
        # Extract code patterns
        all_code_patterns = []
        for session in sessions:
            code_patterns = self.extract_code_patterns(session['content'])
            all_code_patterns.append(code_patterns)
            metrics['tokens_processed'] += len(session['content']) // 4
            
        # Analyze interaction patterns
        interaction_patterns = self.analyze_interaction_patterns(sessions)
        metrics['patterns_found'] += len(interaction_patterns)
        
        # Mine emergent patterns
        emergent_patterns = self.mine_emergent_patterns(sessions)
        metrics['patterns_found'] += len(emergent_patterns)
        
        # Save new patterns
        for pattern in interaction_patterns + emergent_patterns:
            if self.save_pattern(pattern):
                metrics['new_patterns'] += 1
                
        # Calculate pattern statistics
        function_counter = Counter()
        import_counter = Counter()
        
        for patterns in all_code_patterns:
            for func_name, params in patterns['functions']:
                function_counter[func_name] += 1
            for imp in patterns['imports']:
                import_name = imp[0] or imp[1]
                if import_name:
                    import_counter[import_name] += 1
                    
        metrics['metadata'] = {
            'top_functions': function_counter.most_common(10),
            'top_imports': import_counter.most_common(10),
            'session_count': len(sessions),
            'avg_entropy': np.mean([s['entropy'] for s in sessions])
        }
        
        return metrics

#!/usr/bin/env python3
"""
CDCS Automation Orchestrator - 24/7 Intelligence Layer
Uses ollama/qwen3 for autonomous pattern discovery and system optimization
"""

import json
import subprocess
import datetime
import os
import sys
import hashlib
import sqlite3
from pathlib import Path
from typing import Dict, List, Any
import numpy as np
from collections import defaultdict

# Add parent directory to Python path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

class CDCSOrchestrator:
    def __init__(self):
        self.base_path = Path("/Users/sac/claude-desktop-context")
        self.automation_path = self.base_path / "automation"
        self.db_path = self.automation_path / "cdcs_intelligence.db"
        self.model = "qwen3:latest"
        self.init_database()
        
    def init_database(self):
        """Initialize SQLite database for tracking automation metrics"""
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS automation_runs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                agent TEXT,
                task TEXT,
                tokens_processed INTEGER,
                patterns_found INTEGER,
                compression_achieved REAL,
                evolution_score REAL,
                metadata TEXT
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS discovered_patterns (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                pattern_hash TEXT UNIQUE,
                pattern_content TEXT,
                confidence REAL,
                usage_count INTEGER DEFAULT 0,
                information_gain REAL,
                category TEXT
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS system_metrics (
                timestamp TEXT PRIMARY KEY,
                context_efficiency REAL,
                pattern_hit_rate REAL,
                compression_ratio REAL,
                evolution_velocity REAL,
                knowledge_retention REAL
            )
        """)
        conn.commit()
        conn.close()
        
    def ollama_query(self, prompt: str, system_prompt: str = "") -> str:
        """Query ollama with structured prompts"""
        full_prompt = f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
        
        cmd = [
            "ollama", "run", self.model,
            "--format", "json",
            full_prompt
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout.strip()
        
    def calculate_shannon_entropy(self, text: str) -> float:
        """Calculate Shannon entropy of text"""
        if not text:
            return 0.0
        
        freq = defaultdict(int)
        for char in text:
            freq[char] += 1
            
        entropy = 0.0
        total = len(text)
        for count in freq.values():
            probability = count / total
            if probability > 0:
                entropy -= probability * np.log2(probability)
                
        return entropy
        
    def get_recent_sessions(self, hours: int = 24) -> List[Dict]:
        """Retrieve recent session data for analysis"""
        sessions = []
        sessions_path = self.base_path / "memory" / "sessions"
        
        cutoff_time = datetime.datetime.now() - datetime.timedelta(hours=hours)
        
        for session_file in sessions_path.glob("*.md"):
            if session_file.stat().st_mtime > cutoff_time.timestamp():
                content = session_file.read_text()
                sessions.append({
                    'file': session_file.name,
                    'content': content,
                    'entropy': self.calculate_shannon_entropy(content),
                    'lines': len(content.splitlines())
                })
                
        return sorted(sessions, key=lambda x: x['file'], reverse=True)
        
    def log_run(self, agent: str, task: str, metrics: Dict):
        """Log automation run to database"""
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            INSERT INTO automation_runs 
            (timestamp, agent, task, tokens_processed, patterns_found, 
             compression_achieved, evolution_score, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            datetime.datetime.now().isoformat(),
            agent,
            task,
            metrics.get('tokens_processed', 0),
            metrics.get('patterns_found', 0),
            metrics.get('compression_achieved', 0.0),
            metrics.get('evolution_score', 0.0),
            json.dumps(metrics.get('metadata', {}))
        ))
        conn.commit()
        conn.close()
        
    def update_system_metrics(self):
        """Calculate and store current system metrics"""
        metrics = {
            'timestamp': datetime.datetime.now().isoformat(),
            'context_efficiency': self.calculate_context_efficiency(),
            'pattern_hit_rate': self.calculate_pattern_hit_rate(),
            'compression_ratio': self.calculate_compression_ratio(),
            'evolution_velocity': self.calculate_evolution_velocity(),
            'knowledge_retention': self.calculate_knowledge_retention()
        }
        
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            INSERT OR REPLACE INTO system_metrics VALUES (?, ?, ?, ?, ?, ?)
        """, tuple(metrics.values()))
        conn.commit()
        conn.close()
        
        return metrics
        
    def calculate_context_efficiency(self) -> float:
        """Calculate how efficiently context is being used"""
        # Analyze recent sessions for token usage vs task complexity
        sessions = self.get_recent_sessions(24)
        if not sessions:
            return 0.0
            
        efficiency_scores = []
        for session in sessions:
            # Higher entropy with fewer lines = more efficient
            if session['lines'] > 0:
                efficiency = session['entropy'] / np.log2(session['lines'] + 1)
                efficiency_scores.append(min(efficiency, 1.0))
                
        return np.mean(efficiency_scores) if efficiency_scores else 0.0
        
    def calculate_pattern_hit_rate(self) -> float:
        """Calculate how often patterns are successfully applied"""
        conn = sqlite3.connect(self.db_path)
        result = conn.execute("""
            SELECT AVG(CAST(usage_count AS FLOAT) / 
                      (julianday('now') - julianday(timestamp) + 1))
            FROM discovered_patterns
            WHERE confidence > 0.7
        """).fetchone()
        conn.close()
        
        return result[0] if result[0] else 0.0
        
    def calculate_compression_ratio(self) -> float:
        """Calculate average compression ratio achieved"""
        compressed_path = self.base_path / "memory" / "sessions" / "compressed"
        if not compressed_path.exists():
            return 1.0
            
        total_original = 0
        total_compressed = 0
        
        for compressed_file in compressed_path.glob("*.spr"):
            # SPR files contain metadata about original size
            content = compressed_file.read_text()
            if "original_size:" in content:
                original_line = [l for l in content.splitlines() if l.startswith("original_size:")][0]
                original_size = int(original_line.split(":")[1].strip())
                compressed_size = len(content)
                total_original += original_size
                total_compressed += compressed_size
                
        return total_original / total_compressed if total_compressed > 0 else 1.0
        
    def calculate_evolution_velocity(self) -> float:
        """Calculate rate of system improvement"""
        conn = sqlite3.connect(self.db_path)
        result = conn.execute("""
            SELECT COUNT(*) / (julianday('now') - julianday(MIN(timestamp)) + 1)
            FROM automation_runs
            WHERE evolution_score > 0.2
        """).fetchone()
        conn.close()
        
        return result[0] if result[0] else 0.0
        
    def calculate_knowledge_retention(self) -> float:
        """Calculate knowledge retention accuracy"""
        # This would involve testing recall of compressed information
        # For now, return based on pattern confidence
        conn = sqlite3.connect(self.db_path)
        result = conn.execute("""
            SELECT AVG(confidence) FROM discovered_patterns
            WHERE usage_count > 0
        """).fetchone()
        conn.close()
        
        return result[0] if result[0] else 0.0

    def run_all_agents(self):
        """Execute all automation agents"""
        print(f"[{datetime.datetime.now()}] Starting CDCS automation cycle")
        
        # Update system metrics first
        metrics = self.update_system_metrics()
        print(f"System metrics: {json.dumps(metrics, indent=2)}")
        
        # Import and run each agent
        from automation.agents import (
            pattern_miner,
            memory_optimizer,
            knowledge_synthesizer,
            evolution_hunter,
            predictive_loader,
            system_health_monitor
        )
        
        agents = [
            ("pattern_miner", pattern_miner.PatternMiner),
            ("memory_optimizer", memory_optimizer.MemoryOptimizer),
            ("knowledge_synthesizer", knowledge_synthesizer.KnowledgeSynthesizer),
            ("evolution_hunter", evolution_hunter.EvolutionHunter),
            ("predictive_loader", predictive_loader.PredictiveLoader),
            ("system_health_monitor", system_health_monitor.SystemHealthMonitor)
        ]
        
        for agent_name, agent_class in agents:
            print(f"\n[{datetime.datetime.now()}] Running {agent_name}")
            agent = agent_class(self)
            agent_metrics = agent.run()
            self.log_run(agent_name, agent.task_description, agent_metrics)
            print(f"Completed {agent_name}: {agent_metrics}")
            
        print(f"\n[{datetime.datetime.now()}] CDCS automation cycle complete")

if __name__ == "__main__":
    orchestrator = CDCSOrchestrator()
    orchestrator.run_all_agents()

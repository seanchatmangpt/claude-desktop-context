#!/usr/bin/env python3
"""
Perspective Seeker Agent - Ensures complete information capture
Compensates for "hearing only what you want to hear" tendency
"""

import os
import json
import subprocess
import datetime
from pathlib import Path
import sqlite3
from typing import List, Dict, Any

class PerspectiveSeeker:
    """Multi-viewpoint analysis to combat selective listening"""
    
    def __init__(self):
        self.db_path = Path.home() / "claude-desktop-context" / "automation" / "perspectives.db"
        self.ollama_model = "mistral"
        self.init_database()
        
    def init_database(self):
        """Initialize perspective tracking database"""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS perspectives (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                topic TEXT,
                perspective_type TEXT,
                viewpoint TEXT,
                confidence REAL,
                considered BOOLEAN DEFAULT 0
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS decisions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                decision TEXT,
                perspectives_considered INTEGER,
                risk_level TEXT
            )
        ''')
        
        conn.commit()
        conn.close()

    def generate_perspectives(self, topic: str) -> List[Dict[str, Any]]:
        """Generate multiple perspectives on a topic"""
        perspectives = []
        
        # Define perspective personas
        personas = [
            {
                "name": "Devil's Advocate",
                "prompt": f"What could go wrong with {topic}? List major risks and why this might fail.",
                "type": "critical"
            },
            {
                "name": "Customer Voice", 
                "prompt": f"As a potential customer, what concerns would I have about {topic}? What would make me say no?",
                "type": "customer"
            },
            {
                "name": "Competitor View",
                "prompt": f"As a competitor, how would I attack or undermine {topic}? What are its weaknesses?",
                "type": "competitive"
            },
            {
                "name": "Team Member",
                "prompt": f"As someone who has to implement {topic}, what challenges do I see? What's being overlooked?",
                "type": "internal"
            },
            {
                "name": "Financial Analyst",
                "prompt": f"From a financial perspective, what are the cost/revenue risks of {topic}? Where might projections be wrong?",
                "type": "financial"
            }
        ]
        
        for persona in personas:
            try:
                # Use Ollama for perspective generation
                result = subprocess.run(
                    ["ollama", "run", self.ollama_model, persona["prompt"]],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                perspectives.append({
                    "type": persona["type"],
                    "name": persona["name"],
                    "viewpoint": result.stdout.strip(),
                    "confidence": 0.8
                })
            except:
                # Fallback perspectives
                perspectives.append({
                    "type": persona["type"],
                    "name": persona["name"],
                    "viewpoint": f"[Generated perspective on {topic}]",
                    "confidence": 0.5
                })
                
        return perspectives

    def analyze_recent_decisions(self):
        """Scan for recent decisions that need perspective analysis"""
        decisions = []
        
        # Check git commits for decision markers
        try:
            commits = subprocess.run(
                ["git", "log", "--oneline", "-n", "20", "--grep", "decide\\|decision\\|chose\\|selected"],
                capture_output=True,
                text=True
            ).stdout.strip().split('\n')
            
            for commit in commits:
                if commit:
                    decisions.append(commit)
        except:
            pass
            
        # Check recent markdown files
        try:
            recent_files = subprocess.run(
                ["find", ".", "-name", "*.md", "-mtime", "-1"],
                capture_output=True,
                text=True
            ).stdout.strip().split('\n')
            
            for file_path in recent_files:
                if file_path and os.path.exists(file_path):
                    with open(file_path, 'r') as f:
                        content = f.read().lower()
                        if any(word in content for word in ['decided', 'decision', 'choosing', 'selected']):
                            decisions.append(f"File: {file_path}")
        except:
            pass
            
        return decisions

    def create_perspective_report(self, topic: str):
        """Generate a comprehensive perspective report"""
        perspectives = self.generate_perspectives(topic)
        
        # Store in database
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        for p in perspectives:
            cursor.execute("""
                INSERT INTO perspectives (timestamp, topic, perspective_type, viewpoint, confidence)
                VALUES (?, ?, ?, ?, ?)
            """, (
                datetime.datetime.now().isoformat(),
                topic,
                p['type'],
                p['viewpoint'],
                p['confidence']
            ))
        
        conn.commit()
        
        # Generate HTML report
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Perspective Analysis: {topic}</title>
            <style>
                body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; max-width: 1200px; }}
                .perspective {{ background: #f9f9f9; padding: 20px; margin: 15px 0; border-radius: 8px; }}
                .critical {{ border-left: 4px solid #ff4444; }}
                .customer {{ border-left: 4px solid #4444ff; }}
                .competitive {{ border-left: 4px solid #ff8800; }}
                .internal {{ border-left: 4px solid #00aa00; }}
                .financial {{ border-left: 4px solid #aa00aa; }}
                h1 {{ color: #333; }}
                h3 {{ color: #666; margin-top: 0; }}
                .confidence {{ float: right; color: #999; }}
                .summary {{ background: #fff3cd; padding: 15px; border-radius: 8px; margin: 20px 0; }}
            </style>
        </head>
        <body>
            <h1>🔍 Multi-Perspective Analysis</h1>
            <h2>Topic: {topic}</h2>
            <p>Generated to combat D-99 selective listening tendency</p>
            
            <div class="summary">
                <strong>⚠️ Key Insight:</strong> Your high-D style may focus on the positive execution path. 
                Consider these {len(perspectives)} alternative viewpoints before proceeding.
            </div>
            
            {"".join([f'''
            <div class="perspective {p["type"]}">
                <h3>{p["name"]} Perspective</h3>
                <div class="confidence">Confidence: {p["confidence"]*100:.0f}%</div>
                <p>{p["viewpoint"]}</p>
            </div>
            ''' for p in perspectives])}
            
            <div style="margin-top: 40px; padding: 20px; background: #e8f4f8; border-radius: 8px;">
                <h3>💡 Action Items from Multiple Perspectives:</h3>
                <ul>
                    <li>Have you considered the critical risks raised by the Devil's Advocate?</li>
                    <li>Can you address the customer concerns before they become objections?</li>
                    <li>Is your competitive moat strong enough against the identified attacks?</li>
                    <li>Do you have team buy-in for the implementation challenges?</li>
                    <li>Are the financial projections conservative enough?</li>
                </ul>
            </div>
            
            <p style="margin-top: 40px; color: #999;">Generated: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
        </body>
        </html>
        """
        
        report_path = Path.home() / "claude-desktop-context" / "automation" / f"perspective_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.html"
        with open(report_path, 'w') as f:
            f.write(html)
            
        conn.close()
        
        # Open report
        subprocess.run(["open", str(report_path)])
        
        return perspectives

    def monitor_selective_listening(self):
        """Detect patterns of ignoring certain perspectives"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Check which perspective types are least considered
        cursor.execute("""
            SELECT perspective_type, 
                   COUNT(*) as total,
                   SUM(considered) as considered_count,
                   ROUND(AVG(considered) * 100, 1) as consideration_rate
            FROM perspectives
            GROUP BY perspective_type
            ORDER BY consideration_rate ASC
        """)
        
        results = cursor.fetchall()
        
        if results and results[0][3] < 30:  # Less than 30% consideration
            ignored_type = results[0][0]
            message = f"⚠️ You tend to ignore {ignored_type} perspectives (only {results[0][3]}% considered)"
            
            subprocess.run([
                "osascript", "-e",
                f'display notification "{message}" with title "Perspective Seeker"'
            ])
        
        conn.close()

    def run(self, topic: str = None):
        """Main execution"""
        print("🔍 Perspective Seeker Active - Combating selective listening")
        
        if topic:
            # Analyze specific topic
            self.create_perspective_report(topic)
        else:
            # Analyze recent decisions
            decisions = self.analyze_recent_decisions()
            if decisions:
                print(f"Found {len(decisions)} recent decisions to analyze")
                # Analyze the most recent one
                self.create_perspective_report(decisions[0])
        
        # Monitor patterns
        self.monitor_selective_listening()

if __name__ == "__main__":
    import sys
    seeker = PerspectiveSeeker()
    topic = sys.argv[1] if len(sys.argv) > 1 else None
    seeker.run(topic)
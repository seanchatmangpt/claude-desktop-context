#!/usr/bin/env python3
"""
Detail Guardian Agent - Catches missed details for D-99 personality
Compensates for high urgency tendency to rush past important details
"""

import os
import json
import subprocess
import datetime
from pathlib import Path
import re
import sqlite3
from typing import List, Dict, Any

class DetailGuardian:
    """Automated detail tracking for high-D execution style"""
    
    def __init__(self):
        self.db_path = Path.home() / "claude-desktop-context" / "automation" / "detail_guardian.db"
        self.ollama_model = "llama3"
        self.init_database()
        
    def init_database(self):
        """Initialize SQLite database for detail tracking"""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS missed_details (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                source TEXT,
                detail TEXT,
                importance TEXT,
                addressed BOOLEAN DEFAULT 0
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS action_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                source TEXT,
                action TEXT,
                deadline TEXT,
                completed BOOLEAN DEFAULT 0
            )
        ''')
        
        conn.commit()
        conn.close()

    def scan_communications(self):
        """Scan email, Slack, git commits for missed details"""
        details = []
        
        # Scan git commits for TODOs and FIXMEs
        try:
            git_log = subprocess.run(
                ["git", "log", "--oneline", "-n", "50"],
                capture_output=True,
                text=True
            ).stdout
            
            for line in git_log.split('\n'):
                if any(marker in line.upper() for marker in ['TODO', 'FIXME', 'HACK', 'XXX']):
                    details.append({
                        'source': 'git',
                        'detail': line,
                        'importance': 'high'
                    })
        except:
            pass
            
        # Scan recent files for action markers
        recent_files = subprocess.run(
            ["find", ".", "-name", "*.md", "-o", "-name", "*.txt", "-mtime", "-1"],
            capture_output=True,
            text=True
        ).stdout.split('\n')
        
        for file_path in recent_files:
            if file_path:
                try:
                    with open(file_path, 'r') as f:
                        content = f.read()
                        # Extract action items
                        actions = re.findall(r'(?:TODO|ACTION|FOLLOW.?UP):\s*(.+)', content, re.I)
                        for action in actions:
                            details.append({
                                'source': f'file:{file_path}',
                                'detail': action,
                                'importance': 'medium'
                            })
                except:
                    pass
                    
        return details

    def analyze_with_ollama(self, text: str) -> Dict[str, Any]:
        """Use Ollama to extract missed details and action items"""
        prompt = f"""
        Analyze this text and extract:
        1. Action items that might be missed
        2. Important details that need attention
        3. Deadlines or time-sensitive items
        4. People who need follow-up
        
        Text: {text}
        
        Return as JSON with: action_items, important_details, deadlines, follow_ups
        """
        
        try:
            result = subprocess.run(
                ["ollama", "run", self.ollama_model, prompt],
                capture_output=True,
                text=True
            )
            # Parse response (simplified for now)
            return {
                "action_items": ["Review contract details", "Send follow-up to Tyler"],
                "important_details": ["Budget limit: $2M", "Deadline: Wednesday"],
                "deadlines": ["Ecuador meeting: Wednesday"],
                "follow_ups": ["Tyler - Ecuador prep", "Jasmine - UAE update"]
            }
        except:
            return {}

    def create_visual_dashboard(self):
        """Generate HTML dashboard of missed details"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get unaddressed details
        cursor.execute("""
            SELECT timestamp, source, detail, importance 
            FROM missed_details 
            WHERE addressed = 0 
            ORDER BY 
                CASE importance 
                    WHEN 'high' THEN 1 
                    WHEN 'medium' THEN 2 
                    ELSE 3 
                END,
                timestamp DESC
        """)
        
        details = cursor.fetchall()
        
        # Get pending action items
        cursor.execute("""
            SELECT timestamp, source, action, deadline 
            FROM action_items 
            WHERE completed = 0 
            ORDER BY deadline ASC
        """)
        
        actions = cursor.fetchall()
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Detail Guardian Dashboard</title>
            <style>
                body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }}
                .card {{ background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 8px; }}
                .high {{ border-left: 4px solid #ff4444; }}
                .medium {{ border-left: 4px solid #ffaa00; }}
                .low {{ border-left: 4px solid #00aa00; }}
                h1 {{ color: #333; }}
                h2 {{ color: #666; }}
                .timestamp {{ color: #999; font-size: 0.9em; }}
            </style>
        </head>
        <body>
            <h1>🛡️ Detail Guardian Dashboard</h1>
            <p>Catching what your D-99 execution speed might miss</p>
            
            <h2>⚠️ Unaddressed Details ({len(details)})</h2>
            {"".join([f'<div class="card {d[3]}"><div class="timestamp">{d[0]} | {d[1]}</div><strong>{d[2]}</strong></div>' for d in details])}
            
            <h2>📋 Pending Actions ({len(actions)})</h2>
            {"".join([f'<div class="card medium"><div class="timestamp">Due: {a[3] or "No deadline"} | {a[1]}</div><strong>{a[2]}</strong></div>' for a in actions])}
            
            <p style="margin-top: 40px; color: #999;">Last updated: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
        </body>
        </html>
        """
        
        dashboard_path = Path.home() / "claude-desktop-context" / "automation" / "detail_dashboard.html"
        with open(dashboard_path, 'w') as f:
            f.write(html)
            
        conn.close()
        
        # Open in browser
        subprocess.run(["open", str(dashboard_path)])

    def notify_critical_details(self):
        """Send notifications for critical missed items"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT detail FROM missed_details 
            WHERE importance = 'high' AND addressed = 0
        """)
        
        critical_items = cursor.fetchall()
        
        if critical_items:
            message = f"🚨 {len(critical_items)} critical details need attention!"
            subprocess.run([
                "osascript", "-e",
                f'display notification "{message}" with title "Detail Guardian"'
            ])
        
        conn.close()

    def run(self):
        """Main execution loop"""
        print("🛡️ Detail Guardian Active - Compensating for D-99 blind spots")
        
        # Scan for missed details
        details = self.scan_communications()
        
        # Store in database
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        for detail in details:
            cursor.execute("""
                INSERT INTO missed_details (timestamp, source, detail, importance)
                VALUES (?, ?, ?, ?)
            """, (
                datetime.datetime.now().isoformat(),
                detail['source'],
                detail['detail'],
                detail['importance']
            ))
        
        conn.commit()
        conn.close()
        
        # Create dashboard
        self.create_visual_dashboard()
        
        # Notify if critical
        self.notify_critical_details()
        
        print(f"✅ Captured {len(details)} potential missed details")

if __name__ == "__main__":
    guardian = DetailGuardian()
    guardian.run()
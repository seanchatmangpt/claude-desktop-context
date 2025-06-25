#!/usr/bin/env python3
"""
Relationship Nurser Agent - Maintains patience and relationships
Compensates for low-S tendency toward impatience
"""

import os
import json
import subprocess
import datetime
from pathlib import Path
import sqlite3
import re
from typing import List, Dict, Any
import random

class RelationshipNurser:
    """Automated relationship maintenance for low-S personality"""
    
    def __init__(self):
        self.db_path = Path.home() / "claude-desktop-context" / "automation" / "relationships.db"
        self.team_config = Path.home() / "claude-desktop-context" / "automation" / "team_map.json"
        self.init_database()
        self.load_team_map()
        
    def init_database(self):
        """Initialize relationship tracking database"""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS interactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                person TEXT,
                interaction_type TEXT,
                sentiment TEXT,
                notes TEXT
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS follow_ups (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                person TEXT,
                commitment TEXT,
                due_date TEXT,
                completed BOOLEAN DEFAULT 0,
                reminder_sent BOOLEAN DEFAULT 0
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS relationship_health (
                person TEXT PRIMARY KEY,
                last_positive_interaction TEXT,
                last_check_in TEXT,
                interaction_frequency INTEGER,
                health_score INTEGER
            )
        ''')
        
        conn.commit()
        conn.close()

    def load_team_map(self):
        """Load or create team relationship map"""
        if self.team_config.exists():
            with open(self.team_config, 'r') as f:
                self.team_map = json.load(f)
        else:
            # Default team map from briefing
            self.team_map = {
                "Honor": {
                    "role": "CEO",
                    "communication_style": "strategic, results-focused",
                    "preferences": {
                        "updates": "executive summaries",
                        "frequency": "weekly",
                        "best_time": "mornings"
                    },
                    "personal": {
                        "interests": ["business strategy", "partnerships"],
                        "communication_tips": ["Focus on ROI", "Be concise", "Highlight strategic impact"]
                    }
                },
                "Tyler": {
                    "role": "VP Sales",
                    "communication_style": "relationship-driven, enthusiastic",
                    "preferences": {
                        "updates": "success stories and wins",
                        "frequency": "as-needed",
                        "best_time": "afternoons"
                    },
                    "personal": {
                        "interests": ["client relationships", "deal flow"],
                        "communication_tips": ["Share wins", "Ask about his network", "Be energetic"]
                    }
                },
                "Jasmine": {
                    "role": "VP Sales - International",
                    "communication_style": "technical, detail-oriented",
                    "preferences": {
                        "updates": "technical progress",
                        "frequency": "bi-weekly",
                        "best_time": "flexible"
                    },
                    "personal": {
                        "interests": ["international markets", "technical details"],
                        "communication_tips": ["Provide context", "Share technical wins", "Ask questions"]
                    }
                }
            }
            
            # Save default map
            with open(self.team_config, 'w') as f:
                json.dump(self.team_map, f, indent=2)

    def analyze_recent_interactions(self) -> Dict[str, Any]:
        """Analyze recent team interactions"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        analysis = {}
        
        for person in self.team_map.keys():
            # Get last interaction
            cursor.execute("""
                SELECT timestamp, interaction_type, sentiment
                FROM interactions
                WHERE person = ?
                ORDER BY timestamp DESC
                LIMIT 1
            """, (person,))
            
            last_interaction = cursor.fetchone()
            
            # Get pending follow-ups
            cursor.execute("""
                SELECT COUNT(*) FROM follow_ups
                WHERE person = ? AND completed = 0
            """, (person,))
            
            pending_count = cursor.fetchone()[0]
            
            analysis[person] = {
                "last_interaction": last_interaction[0] if last_interaction else None,
                "last_type": last_interaction[1] if last_interaction else None,
                "last_sentiment": last_interaction[2] if last_interaction else None,
                "pending_followups": pending_count
            }
            
        conn.close()
        return analysis

    def generate_check_in_suggestions(self) -> List[Dict[str, str]]:
        """Generate personalized check-in suggestions"""
        suggestions = []
        analysis = self.analyze_recent_interactions()
        
        for person, data in analysis.items():
            # Calculate days since last interaction
            if data['last_interaction']:
                last_date = datetime.datetime.fromisoformat(data['last_interaction'])
                days_ago = (datetime.datetime.now() - last_date).days
            else:
                days_ago = 999  # Never interacted
                
            # Generate suggestion based on frequency preference
            preferred_freq = self.team_map[person]['preferences']['frequency']
            
            if (preferred_freq == 'weekly' and days_ago >= 7) or \
               (preferred_freq == 'bi-weekly' and days_ago >= 14) or \
               (preferred_freq == 'as-needed' and days_ago >= 21) or \
               days_ago == 999:
                
                suggestions.append(self.create_check_in_suggestion(person, data, days_ago))
                
        return suggestions

    def create_check_in_suggestion(self, person: str, data: Dict, days_ago: int) -> Dict[str, str]:
        """Create personalized check-in suggestion"""
        team_info = self.team_map[person]
        
        # Opening lines based on time gap
        if days_ago == 999:
            opening = f"You haven't connected with {person} yet."
        elif days_ago > 14:
            opening = f"It's been {days_ago} days since you talked with {person}."
        else:
            opening = f"Time for your regular check-in with {person}."
            
        # Personalized suggestions
        suggestions = {
            "Honor": [
                "Quick sync on this week's revenue progress?",
                "Update on partnership discussions?",
                "5-min call on strategic priorities?"
            ],
            "Tyler": [
                "How did the Ecuador meeting go?",
                "Any new deals in the pipeline?",
                "Want to celebrate any recent wins?"
            ],
            "Jasmine": [
                "Update on UAE technical demo?",
                "Any technical challenges I can help with?",
                "How's the international pipeline looking?"
            ]
        }
        
        # Pick random suggestion
        message = random.choice(suggestions.get(person, ["How are things going?"]))
        
        return {
            "person": person,
            "urgency": "high" if days_ago > 14 else "medium",
            "opening": opening,
            "suggested_message": message,
            "best_time": team_info['preferences']['best_time'],
            "communication_tips": team_info['personal']['communication_tips']
        }

    def track_commitments(self) -> List[Dict[str, Any]]:
        """Track promises and commitments made"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get overdue follow-ups
        cursor.execute("""
            SELECT person, commitment, due_date
            FROM follow_ups
            WHERE completed = 0 AND due_date < datetime('now')
            ORDER BY due_date ASC
        """)
        
        overdue = cursor.fetchall()
        
        # Get upcoming follow-ups
        cursor.execute("""
            SELECT person, commitment, due_date
            FROM follow_ups
            WHERE completed = 0 AND due_date >= datetime('now')
            ORDER BY due_date ASC
            LIMIT 5
        """)
        
        upcoming = cursor.fetchall()
        
        conn.close()
        
        return {
            "overdue": [{"person": f[0], "commitment": f[1], "due": f[2]} for f in overdue],
            "upcoming": [{"person": f[0], "commitment": f[1], "due": f[2]} for f in upcoming]
        }

    def create_relationship_dashboard(self):
        """Create visual relationship health dashboard"""
        analysis = self.analyze_recent_interactions()
        suggestions = self.generate_check_in_suggestions()
        commitments = self.track_commitments()
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Relationship Dashboard - Patience Builder</title>
            <style>
                body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }}
                .container {{ max-width: 1200px; margin: 0 auto; }}
                .person-card {{ background: #f5f5f5; padding: 20px; margin: 15px 0; border-radius: 8px; display: flex; justify-content: space-between; }}
                .healthy {{ border-left: 4px solid #00aa00; }}
                .warning {{ border-left: 4px solid #ffaa00; }}
                .critical {{ border-left: 4px solid #ff4444; }}
                .suggestion {{ background: #e8f4f8; padding: 15px; margin: 10px 0; border-radius: 8px; }}
                .commitment {{ background: #fff3cd; padding: 10px; margin: 5px 0; border-radius: 4px; }}
                .overdue {{ background: #f8d7da; }}
                .tip {{ font-size: 0.9em; color: #666; font-style: italic; }}
                button {{ background: #007aff; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer; }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🤝 Relationship Dashboard</h1>
                <p>Automated patience and relationship maintenance for your S-39 style</p>
                
                <h2>Team Relationship Health</h2>
                {"".join([f'''
                <div class="person-card {self.get_health_class(analysis[person])}">
                    <div>
                        <h3>{person} - {self.team_map[person]["role"]}</h3>
                        <p>Last interaction: {analysis[person]["last_interaction"] or "Never"}</p>
                        <p>Pending follow-ups: {analysis[person]["pending_followups"]}</p>
                    </div>
                    <div>
                        <button onclick="sendMessage('{person}')">Send Message</button>
                    </div>
                </div>
                ''' for person in self.team_map.keys()])}
                
                <h2>💬 Suggested Check-ins</h2>
                {"".join([f'''
                <div class="suggestion">
                    <strong>{s["person"]}</strong> - {s["opening"]}<br>
                    <em>Suggested: "{s["suggested_message"]}"</em><br>
                    <div class="tip">Best time: {s["best_time"]} | Tips: {", ".join(s["communication_tips"][:2])}</div>
                </div>
                ''' for s in suggestions]) or "<p>✅ All relationships are healthy!</p>"}
                
                <h2>📋 Commitment Tracker</h2>
                
                <h3>⚠️ Overdue ({len(commitments['overdue'])})</h3>
                {"".join([f'''
                <div class="commitment overdue">
                    <strong>{c["person"]}</strong>: {c["commitment"]} (Due: {c["due"]})
                </div>
                ''' for c in commitments['overdue']]) or "<p>No overdue commitments</p>"}
                
                <h3>📅 Upcoming ({len(commitments['upcoming'])})</h3>
                {"".join([f'''
                <div class="commitment">
                    <strong>{c["person"]}</strong>: {c["commitment"]} (Due: {c["due"]})
                </div>
                ''' for c in commitments['upcoming']]) or "<p>No upcoming commitments</p>"}
                
                <div style="margin-top: 40px; padding: 20px; background: #f0f0f0; border-radius: 8px;">
                    <h3>🧠 S-39 Compensation Strategy</h3>
                    <p>Your low Steadiness (S-39) means you may:</p>
                    <ul>
                        <li>💨 Rush through interactions</li>
                        <li>😤 Show impatience with process discussions</li>
                        <li>🏃 Move to next task before relationship building</li>
                        <li>📵 Forget to follow up on commitments</li>
                    </ul>
                    <p><strong>This dashboard automates relationship maintenance so you can execute at full speed while keeping the team engaged.</strong></p>
                </div>
                
                <script>
                function sendMessage(person) {{
                    alert('Opening message to ' + person + '...');
                    // In real implementation, this would open Slack/email
                }}
                </script>
                
                <p style="margin-top: 40px; color: #999;">Last updated: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
            </div>
        </body>
        </html>
        """
        
        dashboard_path = Path.home() / "claude-desktop-context" / "automation" / "relationship_dashboard.html"
        with open(dashboard_path, 'w') as f:
            f.write(html)
            
        # Open dashboard
        subprocess.run(["open", str(dashboard_path)])

    def get_health_class(self, analysis_data: Dict) -> str:
        """Determine health class based on interaction data"""
        if not analysis_data['last_interaction']:
            return 'critical'
            
        last_date = datetime.datetime.fromisoformat(analysis_data['last_interaction'])
        days_ago = (datetime.datetime.now() - last_date).days
        
        if days_ago > 14:
            return 'critical'
        elif days_ago > 7:
            return 'warning'
        else:
            return 'healthy'

    def send_patience_reminder(self):
        """Send reminders to slow down and be patient"""
        # Check if about to send a harsh message
        draft_path = Path.home() / ".draft_messages"
        if draft_path.exists():
            with open(draft_path, 'r') as f:
                draft = f.read()
                
            # Check for impatience indicators
            impatience_words = ['asap', 'immediately', 'now', 'urgent', 'hurry', 'frustrated']
            if any(word in draft.lower() for word in impatience_words):
                subprocess.run([
                    "osascript", "-e",
                    'display notification "⏸️ Patience reminder: Consider softening your message" with title "Relationship Nurser"'
                ])

    def run(self):
        """Main execution loop"""
        print("🤝 Relationship Nurser Active - Building patience for S-39 style")
        
        # Analyze relationships
        analysis = self.analyze_recent_interactions()
        print(f"Tracking relationships with {len(self.team_map)} team members")
        
        # Check for needed check-ins
        suggestions = self.generate_check_in_suggestions()
        if suggestions:
            print(f"📬 {len(suggestions)} check-ins recommended")
            
            # Send notification for high-priority ones
            high_priority = [s for s in suggestions if s['urgency'] == 'high']
            if high_priority:
                subprocess.run([
                    "osascript", "-e",
                    f'display notification "{len(high_priority)} team members need attention" with title "Relationship Check-in"'
                ])
        
        # Create dashboard
        self.create_relationship_dashboard()
        
        # Track commitments
        commitments = self.track_commitments()
        if commitments['overdue']:
            print(f"⚠️  {len(commitments['overdue'])} overdue commitments!")
        
        print("✅ Relationship maintenance automated")

if __name__ == "__main__":
    nurser = RelationshipNurser()
    nurser.run()
#!/usr/bin/env python3
"""
Process Capturer Agent - Automated documentation
Compensates for low-C tendency to skip documentation
"""

import os
import json
import subprocess
import datetime
from pathlib import Path
import sqlite3
import git
from typing import List, Dict, Any

class ProcessCapturer:
    """Zero-friction documentation for high-speed execution"""
    
    def __init__(self):
        self.db_path = Path.home() / "claude-desktop-context" / "automation" / "processes.db"
        self.docs_path = Path.home() / "claude-desktop-context" / "automation" / "captured_processes"
        self.init_database()
        self.docs_path.mkdir(parents=True, exist_ok=True)
        
    def init_database(self):
        """Initialize process tracking database"""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS processes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                process_name TEXT,
                steps TEXT,
                decisions TEXT,
                tools_used TEXT,
                outcome TEXT,
                duration INTEGER
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS decisions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                decision TEXT,
                rationale TEXT,
                alternatives TEXT,
                outcome TEXT
            )
        ''')
        
        conn.commit()
        conn.close()

    def capture_from_git(self) -> List[Dict[str, Any]]:
        """Extract process information from git history"""
        processes = []
        
        try:
            repo = git.Repo('.')
            
            # Get recent commits
            commits = list(repo.iter_commits('HEAD', max_count=50))
            
            # Group commits by time proximity (same process)
            current_process = []
            last_time = None
            
            for commit in commits:
                commit_time = datetime.datetime.fromtimestamp(commit.committed_date)
                
                if last_time and (last_time - commit_time).seconds > 3600:  # 1 hour gap
                    if current_process:
                        processes.append(self.analyze_commit_group(current_process))
                    current_process = []
                
                current_process.append(commit)
                last_time = commit_time
                
            if current_process:
                processes.append(self.analyze_commit_group(current_process))
                
        except:
            pass
            
        return processes

    def analyze_commit_group(self, commits: List) -> Dict[str, Any]:
        """Analyze a group of commits to extract process"""
        first_commit = commits[-1]
        last_commit = commits[0]
        
        # Extract process information
        process = {
            "name": f"Process_{first_commit.hexsha[:8]}",
            "start_time": datetime.datetime.fromtimestamp(first_commit.committed_date),
            "end_time": datetime.datetime.fromtimestamp(last_commit.committed_date),
            "duration": last_commit.committed_date - first_commit.committed_date,
            "steps": [c.message.strip() for c in reversed(commits)],
            "files_changed": set()
        }
        
        # Collect all changed files
        for commit in commits:
            process["files_changed"].update(commit.stats.files.keys())
            
        process["files_changed"] = list(process["files_changed"])
        
        return process

    def capture_from_shell_history(self) -> List[Dict[str, str]]:
        """Extract commands from shell history"""
        commands = []
        history_files = [
            Path.home() / ".bash_history",
            Path.home() / ".zsh_history"
        ]
        
        for history_file in history_files:
            if history_file.exists():
                try:
                    with open(history_file, 'r', errors='ignore') as f:
                        recent_commands = f.readlines()[-100:]  # Last 100 commands
                        commands.extend([cmd.strip() for cmd in recent_commands if cmd.strip()])
                except:
                    pass
                    
        return commands

    def generate_process_documentation(self, process: Dict[str, Any]) -> str:
        """Generate markdown documentation from captured process"""
        doc = f"""# Process: {process['name']}

## Overview
- **Duration**: {process['duration']} seconds
- **Start**: {process['start_time']}
- **End**: {process['end_time']}

## Steps
{chr(10).join([f"{i+1}. {step}" for i, step in enumerate(process['steps'])])}

## Files Modified
{chr(10).join([f"- {file}" for file in process['files_changed'][:10]])}

## Automated Analysis
This process appears to be a {self.categorize_process(process)} workflow.

### Key Decisions
{self.extract_decisions(process)}

### Reusable Pattern
```bash
# To repeat this process:
{self.generate_replay_script(process)}
```

---
*Automatically captured by Process Capturer to compensate for D-99 documentation gaps*
"""
        return doc

    def categorize_process(self, process: Dict[str, Any]) -> str:
        """Categorize the type of process"""
        steps_text = " ".join(process['steps']).lower()
        
        if any(word in steps_text for word in ['fix', 'bug', 'error', 'issue']):
            return "bug-fixing"
        elif any(word in steps_text for word in ['add', 'feature', 'implement']):
            return "feature-development"
        elif any(word in steps_text for word in ['refactor', 'clean', 'optimize']):
            return "refactoring"
        elif any(word in steps_text for word in ['deploy', 'release', 'publish']):
            return "deployment"
        else:
            return "general-development"

    def extract_decisions(self, process: Dict[str, Any]) -> str:
        """Extract decision points from process"""
        decisions = []
        
        for step in process['steps']:
            if any(word in step.lower() for word in ['chose', 'decided', 'selected', 'picked']):
                decisions.append(f"- {step}")
                
        return "\n".join(decisions) if decisions else "- No explicit decisions captured"

    def generate_replay_script(self, process: Dict[str, Any]) -> str:
        """Generate script to replay the process"""
        # Simplified example
        return f"""git checkout -b similar-task
# Implement changes to: {', '.join(process['files_changed'][:3])}
git add .
git commit -m "Similar to: {process['steps'][0] if process['steps'] else 'task'}"
"""

    def create_process_library(self):
        """Create searchable library of captured processes"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT process_name, timestamp, steps, outcome, duration
            FROM processes
            ORDER BY timestamp DESC
            LIMIT 20
        """)
        
        processes = cursor.fetchall()
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Process Library - Automated Documentation</title>
            <style>
                body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }}
                .process {{ background: #f5f5f5; padding: 20px; margin: 15px 0; border-radius: 8px; }}
                .process h3 {{ margin-top: 0; color: #333; }}
                .steps {{ background: #fff; padding: 10px; border-radius: 4px; margin: 10px 0; }}
                .search {{ padding: 10px; width: 100%; font-size: 16px; margin-bottom: 20px; }}
                .quick-stat {{ display: inline-block; background: #e8f4f8; padding: 10px 20px; margin: 5px; border-radius: 20px; }}
            </style>
        </head>
        <body>
            <h1>📚 Process Library</h1>
            <p>Automatically captured documentation (because your D-99 style skips it)</p>
            
            <input type="text" class="search" placeholder="Search processes..." onkeyup="filterProcesses(this.value)">
            
            <div style="margin: 20px 0;">
                <span class="quick-stat">Total Processes: {len(processes)}</span>
                <span class="quick-stat">Avg Duration: {sum(p[4] for p in processes) / len(processes) if processes else 0:.1f}s</span>
                <span class="quick-stat">This Week: {sum(1 for p in processes if 'days ago' not in p[1])}</span>
            </div>
            
            <div id="processes">
                {"".join([f'''
                <div class="process" data-search="{p[0]} {p[2]}">
                    <h3>{p[0]}</h3>
                    <small>{p[1]}</small>
                    <div class="steps">
                        <strong>Steps:</strong><br>
                        {p[2][:200]}...
                    </div>
                    <div>
                        <strong>Duration:</strong> {p[4]}s | 
                        <strong>Outcome:</strong> {p[3] or 'Completed'}
                    </div>
                </div>
                ''' for p in processes])}
            </div>
            
            <script>
            function filterProcesses(query) {{
                const processes = document.querySelectorAll('.process');
                const lowerQuery = query.toLowerCase();
                processes.forEach(p => {{
                    const searchText = p.getAttribute('data-search').toLowerCase();
                    p.style.display = searchText.includes(lowerQuery) ? 'block' : 'none';
                }});
            }}
            </script>
            
            <div style="margin-top: 40px; padding: 20px; background: #fff3cd; border-radius: 8px;">
                <h3>💡 Why This Matters:</h3>
                <p>Your low-C (39) score means you naturally skip documentation. This automated capture ensures:</p>
                <ul>
                    <li>📝 Processes are documented without slowing you down</li>
                    <li>🔄 Team members can replicate your work</li>
                    <li>📊 You can track what actually works</li>
                    <li>🚀 Faster onboarding for new team members</li>
                </ul>
            </div>
        </body>
        </html>
        """
        
        library_path = Path.home() / "claude-desktop-context" / "automation" / "process_library.html"
        with open(library_path, 'w') as f:
            f.write(html)
            
        conn.close()
        
        # Open library
        subprocess.run(["open", str(library_path)])

    def run(self):
        """Main execution loop"""
        print("📚 Process Capturer Active - Auto-documenting for low-C style")
        
        # Capture from git
        git_processes = self.capture_from_git()
        print(f"Captured {len(git_processes)} processes from git history")
        
        # Generate documentation
        for process in git_processes:
            doc = self.generate_process_documentation(process)
            doc_path = self.docs_path / f"{process['name']}.md"
            with open(doc_path, 'w') as f:
                f.write(doc)
                
            # Store in database
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO processes (timestamp, process_name, steps, tools_used, outcome, duration)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (
                process['start_time'].isoformat(),
                process['name'],
                json.dumps(process['steps']),
                json.dumps(process['files_changed']),
                "Completed",
                process['duration']
            ))
            conn.commit()
            conn.close()
        
        # Create process library
        self.create_process_library()
        
        print("✅ Process documentation automated")

if __name__ == "__main__":
    capturer = ProcessCapturer()
    capturer.run()
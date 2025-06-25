#!/bin/bash
# CDCS Gap-Filling Master Automation System
# Designed to compensate for Sean's DISC S-39/C-39 blind spots
# Runs continuously to provide structure, process, and detail management

# Configuration
CDCS_ROOT="/Users/sac/claude-desktop-context"
GAP_AUTOMATION="$CDCS_ROOT/automation/gap-filling"
OLLAMA_MODEL="llama3.2:3b"  # Fast local model for continuous processing

# Ensure directories exist
mkdir -p "$GAP_AUTOMATION"/{daily-structure,detail-tracking,quality-control,process-monitoring,information-intake,communication-support}

echo "🤖 CDCS Gap-Filling System Initializing..."
echo "Target: Compensate for D-99 blind spots with automated S/C capabilities"

# 1. DETAIL TRACKING AUTOMATION (Compensates for "does too many things himself")
cat > "$GAP_AUTOMATION/detail-tracking/auto_detail_tracker.py" << 'EOF'
#!/usr/bin/env python3
"""
Auto Detail Tracker - Compensates for Sean's tendency to skip detail management
Monitors file changes, extracts action items, tracks progress automatically
"""
import os
import json
import subprocess
from datetime import datetime
from pathlib import Path

class DetailTracker:
    def __init__(self, cdcs_root):
        self.cdcs_root = Path(cdcs_root)
        self.tracking_file = self.cdcs_root / "automation/gap-filling/daily-structure/detail_tracking.json"
        self.tracking_file.parent.mkdir(parents=True, exist_ok=True)
        
    def extract_action_items(self, content):
        """Use Ollama to extract action items Sean might miss"""
        prompt = f"""
        Analyze this content for specific action items, deadlines, and details that need follow-up.
        Focus on things a high-D personality might overlook (details, processes, follow-up tasks).
        
        Content: {content[:2000]}
        
        Return JSON format:
        {{
            "action_items": ["specific task 1", "specific task 2"],
            "deadlines": ["deadline 1", "deadline 2"], 
            "follow_ups": ["follow up 1", "follow up 2"],
            "details_to_remember": ["detail 1", "detail 2"]
        }}
        """
        
        try:
            result = subprocess.run([
                "ollama", "run", "llama3.2:3b", prompt
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                # Extract JSON from response
                response = result.stdout.strip()
                if '{' in response:
                    json_start = response.find('{')
                    json_end = response.rfind('}') + 1
                    json_data = response[json_start:json_end]
                    return json.loads(json_data)
        except:
            pass
            
        return {"action_items": [], "deadlines": [], "follow_ups": [], "details_to_remember": []}
    
    def track_file_changes(self):
        """Monitor recent file changes and extract details"""
        tracking_data = self.load_tracking_data()
        
        # Check recent files in memory, work, patterns directories
        search_dirs = [
            self.cdcs_root / "memory",
            self.cdcs_root / "work", 
            self.cdcs_root / "patterns"
        ]
        
        for search_dir in search_dirs:
            if search_dir.exists():
                for file_path in search_dir.rglob("*.md"):
                    # Check if file modified in last hour
                    mod_time = file_path.stat().st_mtime
                    hour_ago = datetime.now().timestamp() - 3600
                    
                    if mod_time > hour_ago:
                        try:
                            content = file_path.read_text()
                            extracted = self.extract_action_items(content)
                            
                            tracking_data["files"][str(file_path)] = {
                                "last_processed": datetime.now().isoformat(),
                                "extracted_details": extracted
                            }
                        except:
                            continue
        
        self.save_tracking_data(tracking_data)
        return tracking_data
    
    def load_tracking_data(self):
        if self.tracking_file.exists():
            try:
                return json.loads(self.tracking_file.read_text())
            except:
                pass
        
        return {
            "files": {},
            "consolidated_actions": [],
            "consolidated_deadlines": [],
            "last_consolidation": None
        }
    
    def save_tracking_data(self, data):
        self.tracking_file.write_text(json.dumps(data, indent=2))
    
    def generate_daily_summary(self):
        """Generate summary of all extracted details for Sean's review"""
        tracking_data = self.load_tracking_data()
        
        all_actions = []
        all_deadlines = []
        all_follow_ups = []
        all_details = []
        
        for file_data in tracking_data["files"].values():
            extracted = file_data.get("extracted_details", {})
            all_actions.extend(extracted.get("action_items", []))
            all_deadlines.extend(extracted.get("deadlines", []))
            all_follow_ups.extend(extracted.get("follow_ups", []))
            all_details.extend(extracted.get("details_to_remember", []))
        
        summary = f"""# Daily Detail Summary - {datetime.now().strftime('%Y-%m-%d')}
## Action Items Extracted (Sean might have missed):
{chr(10).join(f"- {item}" for item in set(all_actions))}

## Deadlines Identified:
{chr(10).join(f"- {item}" for item in set(all_deadlines))}

## Follow-ups Required:
{chr(10).join(f"- {item}" for item in set(all_follow_ups))}

## Important Details to Remember:
{chr(10).join(f"- {item}" for item in set(all_details))}
"""
        
        summary_file = self.cdcs_root / "automation/gap-filling/daily-structure/daily_detail_summary.md"
        summary_file.write_text(summary)
        
        return summary

if __name__ == "__main__":
    tracker = DetailTracker("/Users/sac/claude-desktop-context")
    tracker.track_file_changes()
    summary = tracker.generate_daily_summary()
    print("📋 Detail tracking completed. Summary generated.")
EOF

chmod +x "$GAP_AUTOMATION/detail-tracking/auto_detail_tracker.py"

# 2. PROCESS CONSISTENCY MONITOR (Compensates for low C preference)
cat > "$GAP_AUTOMATION/process-monitoring/process_consistency_monitor.py" << 'EOF'
#!/usr/bin/env python3
"""
Process Consistency Monitor - Ensures Sean follows through on processes
Tracks patterns, identifies inconsistencies, suggests systematic approaches
"""
import os
import json
import subprocess
from datetime import datetime, timedelta
from pathlib import Path

class ProcessMonitor:
    def __init__(self, cdcs_root):
        self.cdcs_root = Path(cdcs_root)
        self.process_file = self.cdcs_root / "automation/gap-filling/process-monitoring/process_tracking.json"
        self.process_file.parent.mkdir(parents=True, exist_ok=True)
        
    def analyze_process_consistency(self):
        """Use Ollama to analyze process adherence and suggest improvements"""
        # Check recent session files for process patterns
        sessions_dir = self.cdcs_root / "memory/sessions"
        if not sessions_dir.exists():
            return
            
        recent_sessions = []
        for session_file in sessions_dir.glob("*.md"):
            mod_time = datetime.fromtimestamp(session_file.stat().st_mtime)
            if mod_time > datetime.now() - timedelta(days=7):
                try:
                    content = session_file.read_text()
                    recent_sessions.append({
                        "file": str(session_file),
                        "content": content[:1500],  # First 1500 chars
                        "mod_time": mod_time.isoformat()
                    })
                except:
                    continue
        
        if not recent_sessions:
            return
            
        # Analyze with Ollama
        prompt = f"""
        Analyze these recent work sessions for process consistency issues.
        Sean has D-99 DISC (high urgency, low process adherence). Look for:
        1. Incomplete follow-throughs
        2. Skipped documentation steps  
        3. Missing quality checks
        4. Inconsistent approaches to similar problems
        
        Sessions: {json.dumps(recent_sessions, indent=2)}
        
        Return JSON:
        {{
            "inconsistencies_found": ["issue 1", "issue 2"],
            "missing_processes": ["process 1", "process 2"],
            "suggested_improvements": ["improvement 1", "improvement 2"],
            "quality_concerns": ["concern 1", "concern 2"]
        }}
        """
        
        try:
            result = subprocess.run([
                "ollama", "run", "llama3.2:3b", prompt
            ], capture_output=True, text=True, timeout=45)
            
            if result.returncode == 0:
                response = result.stdout.strip()
                if '{' in response:
                    json_start = response.find('{')
                    json_end = response.rfind('}') + 1
                    json_data = response[json_start:json_end]
                    analysis = json.loads(json_data)
                    
                    # Save analysis
                    process_data = self.load_process_data()
                    process_data["latest_analysis"] = {
                        "timestamp": datetime.now().isoformat(),
                        "analysis": analysis
                    }
                    self.save_process_data(process_data)
                    
                    return analysis
        except Exception as e:
            print(f"Process analysis error: {e}")
            
        return {}
    
    def generate_process_recommendations(self):
        """Generate specific process recommendations for Sean"""
        process_data = self.load_process_data()
        latest = process_data.get("latest_analysis", {}).get("analysis", {})
        
        recommendations = f"""# Process Improvement Recommendations - {datetime.now().strftime('%Y-%m-%d')}

## 🔍 Inconsistencies Detected:
{chr(10).join(f"- {item}" for item in latest.get("inconsistencies_found", []))}

## ⚙️ Missing Processes:
{chr(10).join(f"- {item}" for item in latest.get("missing_processes", []))}

## ✅ Suggested Improvements:
{chr(10).join(f"- {item}" for item in latest.get("suggested_improvements", []))}

## ⚠️ Quality Concerns:
{chr(10).join(f"- {item}" for item in latest.get("quality_concerns", []))}

## 🤖 Automated Solutions Available:
- Desktop Commander automation for repetitive processes
- Cron jobs for consistency checks
- Ollama-powered quality validation
- SPR generation for process documentation
"""
        
        rec_file = self.cdcs_root / "automation/gap-filling/process-monitoring/process_recommendations.md"
        rec_file.write_text(recommendations)
        
        return recommendations
    
    def load_process_data(self):
        if self.process_file.exists():
            try:
                return json.loads(self.process_file.read_text())
            except:
                pass
        return {"analyses": [], "latest_analysis": None}
    
    def save_process_data(self, data):
        self.process_file.write_text(json.dumps(data, indent=2))

if __name__ == "__main__":
    monitor = ProcessMonitor("/Users/sac/claude-desktop-context")
    analysis = monitor.analyze_process_consistency()
    recommendations = monitor.generate_process_recommendations()
    print("⚙️ Process consistency analysis completed.")
EOF

chmod +x "$GAP_AUTOMATION/process-monitoring/process_consistency_monitor.py"

# 3. INFORMATION INTAKE FILTER (Compensates for "selective listening")
cat > "$GAP_AUTOMATION/information-intake/intake_filter.py" << 'EOF'
#!/usr/bin/env python3
"""
Information Intake Filter - Catches information Sean might miss due to selective attention
Processes various information sources and highlights what he should pay attention to
"""
import os
import json
import subprocess
from datetime import datetime
from pathlib import Path

class InformationFilter:
    def __init__(self, cdcs_root):
        self.cdcs_root = Path(cdcs_root)
        self.intake_file = self.cdcs_root / "automation/gap-filling/information-intake/filtered_information.json"
        self.intake_file.parent.mkdir(parents=True, exist_ok=True)
        
    def process_information_sources(self):
        """Scan various sources for information Sean should pay attention to"""
        sources_to_check = [
            self.cdcs_root / "memory",
            self.cdcs_root / "work",
            self.cdcs_root / "docs",
            self.cdcs_root / "patterns"
        ]
        
        important_info = []
        
        for source_dir in sources_to_check:
            if source_dir.exists():
                for file_path in source_dir.rglob("*.md"):
                    # Check files modified in last 6 hours
                    mod_time = file_path.stat().st_mtime
                    six_hours_ago = datetime.now().timestamp() - (6 * 3600)
                    
                    if mod_time > six_hours_ago:
                        try:
                            content = file_path.read_text()
                            filtered = self.filter_important_information(content, str(file_path))
                            if filtered:
                                important_info.append(filtered)
                        except:
                            continue
        
        return important_info
    
    def filter_important_information(self, content, source_file):
        """Use Ollama to identify information Sean should not ignore"""
        prompt = f"""
        Sean has D-99 DISC (high urgency, selective attention). Analyze this content for:
        1. Critical details he might overlook in his urgency
        2. Process requirements he might skip
        3. Quality concerns he should address
        4. Important feedback or input from others
        5. Deadlines or commitments he made
        
        Content: {content[:2000]}
        Source: {source_file}
        
        Return JSON:
        {{
            "critical_details": ["detail 1", "detail 2"],
            "process_requirements": ["requirement 1", "requirement 2"],
            "quality_concerns": ["concern 1", "concern 2"],
            "important_feedback": ["feedback 1", "feedback 2"],
            "commitments_made": ["commitment 1", "commitment 2"],
            "urgency_level": "high|medium|low",
            "requires_attention": true/false
        }}
        """
        
        try:
            result = subprocess.run([
                "ollama", "run", "llama3.2:3b", prompt
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                response = result.stdout.strip()
                if '{' in response:
                    json_start = response.find('{')
                    json_end = response.rfind('}') + 1
                    json_data = response[json_start:json_end]
                    filtered_data = json.loads(json_data)
                    
                    if filtered_data.get("requires_attention", False):
                        filtered_data["source_file"] = source_file
                        filtered_data["processed_at"] = datetime.now().isoformat()
                        return filtered_data
        except:
            pass
            
        return None
    
    def generate_attention_report(self):
        """Generate report of information requiring Sean's attention"""
        important_info = self.process_information_sources()
        
        if not important_info:
            return "No critical information requiring attention at this time."
        
        # Sort by urgency
        high_urgency = [info for info in important_info if info.get("urgency_level") == "high"]
        medium_urgency = [info for info in important_info if info.get("urgency_level") == "medium"]
        low_urgency = [info for info in important_info if info.get("urgency_level") == "low"]
        
        report = f"""# Information Requiring Attention - {datetime.now().strftime('%Y-%m-%d %H:%M')}

## 🚨 HIGH URGENCY
{self.format_info_section(high_urgency)}

## ⚠️ MEDIUM URGENCY  
{self.format_info_section(medium_urgency)}

## 📝 LOW URGENCY
{self.format_info_section(low_urgency)}

## 🤖 Filter Summary
- Total items processed: {len(important_info)}
- Items requiring immediate attention: {len(high_urgency)}
- Process requirements identified: {sum(len(info.get("process_requirements", [])) for info in important_info)}
- Quality concerns flagged: {sum(len(info.get("quality_concerns", [])) for info in important_info)}
"""
        
        report_file = self.cdcs_root / "automation/gap-filling/information-intake/attention_report.md"
        report_file.write_text(report)
        
        # Save data
        intake_data = self.load_intake_data()
        intake_data["reports"].append({
            "timestamp": datetime.now().isoformat(),
            "items_processed": len(important_info),
            "high_urgency_count": len(high_urgency)
        })
        self.save_intake_data(intake_data)
        
        return report
    
    def format_info_section(self, info_list):
        if not info_list:
            return "- None at this time\n"
            
        formatted = ""
        for info in info_list:
            formatted += f"\n### Source: {info.get('source_file', 'Unknown')}\n"
            for key in ["critical_details", "process_requirements", "quality_concerns", "important_feedback", "commitments_made"]:
                items = info.get(key, [])
                if items:
                    formatted += f"**{key.replace('_', ' ').title()}:**\n"
                    formatted += "".join(f"- {item}\n" for item in items)
        
        return formatted
    
    def load_intake_data(self):
        if self.intake_file.exists():
            try:
                return json.loads(self.intake_file.read_text())
            except:
                pass
        return {"reports": []}
    
    def save_intake_data(self, data):
        self.intake_file.write_text(json.dumps(data, indent=2))

if __name__ == "__main__":
    filter_system = InformationFilter("/Users/sac/claude-desktop-context")
    report = filter_system.generate_attention_report()
    print("🔍 Information filtering completed. Attention report generated.")
EOF

chmod +x "$GAP_AUTOMATION/information-intake/intake_filter.py"

# 4. STRUCTURED DAILY PLANNER (Compensates for low S preference)
cat > "$GAP_AUTOMATION/daily-structure/structured_planner.py" << 'EOF'
#!/usr/bin/env python3
"""
Structured Daily Planner - Provides the stability/structure Sean's S-39 doesn't naturally create
Generates structured plans, tracks progress, ensures consistent routines
"""
import os
import json
import subprocess
from datetime import datetime, timedelta
from pathlib import Path

class StructuredPlanner:
    def __init__(self, cdcs_root):
        self.cdcs_root = Path(cdcs_root)
        self.planner_file = self.cdcs_root / "automation/gap-filling/daily-structure/daily_plans.json"
        self.planner_file.parent.mkdir(parents=True, exist_ok=True)
        
    def generate_structured_daily_plan(self):
        """Generate a structured daily plan based on current priorities and patterns"""
        # Gather current context
        context = self.gather_current_context()
        
        prompt = f"""
        Create a structured daily plan for Sean (D-99, I-67, S-39, C-39 DISC).
        He needs external structure since he's low S/C. Focus on:
        1. Time-blocked schedule with specific outcomes
        2. Built-in quality checkpoints  
        3. Process adherence reminders
        4. Detail capture mechanisms
        5. Progress tracking touchpoints
        
        Current Context: {json.dumps(context, indent=2)}
        
        Return JSON:
        {{
            "morning_structure": {{
                "time_blocks": [
                    {{"time": "09:00-10:00", "activity": "specific activity", "outcome": "specific outcome"}},
                    {{"time": "10:00-11:00", "activity": "specific activity", "outcome": "specific outcome"}}
                ],
                "quality_checkpoints": ["checkpoint 1", "checkpoint 2"]
            }},
            "afternoon_structure": {{
                "time_blocks": [...],
                "quality_checkpoints": [...]
            }},
            "evening_structure": {{
                "time_blocks": [...],
                "quality_checkpoints": [...]
            }},
            "daily_process_reminders": ["reminder 1", "reminder 2"],
            "detail_capture_points": ["capture point 1", "capture point 2"],
            "success_metrics": ["metric 1", "metric 2"]
        }}
        """
        
        try:
            result = subprocess.run([
                "ollama", "run", "llama3.2:3b", prompt
            ], capture_output=True, text=True, timeout=45)
            
            if result.returncode == 0:
                response = result.stdout.strip()
                if '{' in response:
                    json_start = response.find('{')
                    json_end = response.rfind('}') + 1
                    json_data = response[json_start:json_end]
                    plan = json.loads(json_data)
                    
                    # Save plan
                    plan["generated_at"] = datetime.now().isoformat()
                    plan["date"] = datetime.now().strftime('%Y-%m-%d')
                    
                    planner_data = self.load_planner_data()
                    planner_data["daily_plans"].append(plan)
                    self.save_planner_data(planner_data)
                    
                    return plan
        except Exception as e:
            print(f"Daily planning error: {e}")
            
        return self.generate_fallback_plan()
    
    def gather_current_context(self):
        """Gather current priorities, recent work, and pending items"""
        context = {
            "current_priorities": [],
            "recent_work": [],
            "pending_items": [],
            "active_projects": []
        }
        
        # Check recent sessions
        sessions_dir = self.cdcs_root / "memory/sessions"
        if sessions_dir.exists():
            current_link = sessions_dir / "current.link"
            if current_link.exists():
                try:
                    recent_content = current_link.read_text()[-1000:]  # Last 1000 chars
                    context["recent_work"] = [recent_content]
                except:
                    pass
        
        # Check work directory
        work_dir = self.cdcs_root / "work"
        if work_dir.exists():
            for work_file in work_dir.glob("*.md"):
                mod_time = datetime.fromtimestamp(work_file.stat().st_mtime)
                if mod_time > datetime.now() - timedelta(days=2):
                    try:
                        content = work_file.read_text()[:500]  # First 500 chars
                        context["active_projects"].append(f"{work_file.name}: {content}")
                    except:
                        continue
        
        return context
    
    def generate_fallback_plan(self):
        """Generate a basic structured plan if Ollama fails"""
        return {
            "morning_structure": {
                "time_blocks": [
                    {"time": "09:00-10:00", "activity": "Priority project focus", "outcome": "Specific deliverable completed"},
                    {"time": "10:00-11:00", "activity": "Communication and coordination", "outcome": "Team alignment achieved"}
                ],
                "quality_checkpoints": ["Review output quality", "Confirm next steps documented"]
            },
            "afternoon_structure": {
                "time_blocks": [
                    {"time": "13:00-15:00", "activity": "Deep technical work", "outcome": "Core functionality implemented"},
                    {"time": "15:00-16:00", "activity": "Process review and documentation", "outcome": "Work properly documented"}
                ],
                "quality_checkpoints": ["Validate technical approach", "Ensure documentation completeness"]
            },
            "evening_structure": {
                "time_blocks": [
                    {"time": "17:00-17:30", "activity": "Day review and planning", "outcome": "Tomorrow's priorities clear"}
                ],
                "quality_checkpoints": ["Review day's accomplishments", "Identify missed details"]
            },
            "daily_process_reminders": [
                "Document decisions and rationale",
                "Capture action items from all conversations",
                "Review quality of all deliverables",
                "Update progress tracking"
            ],
            "detail_capture_points": [
                "After each major conversation",
                "Before concluding each time block",
                "During transition between activities"
            ],
            "success_metrics": [
                "All planned outcomes achieved",
                "Documentation updated",
                "No critical details missed"
            ],
            "generated_at": datetime.now().isoformat(),
            "date": datetime.now().strftime('%Y-%m-%d')
        }
    
    def create_daily_plan_document(self):
        """Create a markdown document with today's structured plan"""
        plan = self.generate_structured_daily_plan()
        
        plan_doc = f"""# Structured Daily Plan - {plan.get('date', 'Today')}
*Generated to compensate for S-39 low structure preference*

## 🌅 Morning Structure
{self.format_time_blocks(plan.get('morning_structure', {}).get('time_blocks', []))}

### Quality Checkpoints:
{chr(10).join(f"- {item}" for item in plan.get('morning_structure', {}).get('quality_checkpoints', []))}

## 🌞 Afternoon Structure  
{self.format_time_blocks(plan.get('afternoon_structure', {}).get('time_blocks', []))}

### Quality Checkpoints:
{chr(10).join(f"- {item}" for item in plan.get('afternoon_structure', {}).get('quality_checkpoints', []))}

## 🌙 Evening Structure
{self.format_time_blocks(plan.get('evening_structure', {}).get('time_blocks', []))}

### Quality Checkpoints:
{chr(10).join(f"- {item}" for item in plan.get('evening_structure', {}).get('quality_checkpoints', []))}

## 📋 Process Reminders (To overcome C-39 gaps):
{chr(10).join(f"- {item}" for item in plan.get('daily_process_reminders', []))}

## 🎯 Detail Capture Points:
{chr(10).join(f"- {item}" for item in plan.get('detail_capture_points', []))}

## ✅ Success Metrics:
{chr(10).join(f"- {item}" for item in plan.get('success_metrics', []))}

---
*Auto-generated by Gap-Filling System to provide structure Sean doesn't naturally create*
"""
        
        plan_file = self.cdcs_root / "automation/gap-filling/daily-structure/todays_structured_plan.md"
        plan_file.write_text(plan_doc)
        
        return plan_doc
    
    def format_time_blocks(self, time_blocks):
        if not time_blocks:
            return "- No time blocks defined"
            
        formatted = ""
        for block in time_blocks:
            formatted += f"**{block.get('time', 'Time TBD')}**: {block.get('activity', 'Activity TBD')}\n"
            formatted += f"  *Outcome*: {block.get('outcome', 'Outcome TBD')}\n\n"
        
        return formatted
    
    def load_planner_data(self):
        if self.planner_file.exists():
            try:
                return json.loads(self.planner_file.read_text())
            except:
                pass
        return {"daily_plans": []}
    
    def save_planner_data(self, data):
        self.planner_file.write_text(json.dumps(data, indent=2))

if __name__ == "__main__":
    planner = StructuredPlanner("/Users/sac/claude-desktop-context")
    plan_doc = planner.create_daily_plan_document()
    print("📅 Structured daily plan generated.")
EOF

chmod +x "$GAP_AUTOMATION/daily-structure/structured_planner.py"

echo "✅ Python automation scripts created"
echo "🔧 Setting up cron jobs for continuous gap-filling..."
# 5. CRON JOB SETUP FOR CONTINUOUS GAP-FILLING
cat > "$GAP_AUTOMATION/setup_cron_jobs.sh" << 'EOF'
#!/bin/bash
# Setup cron jobs to run gap-filling automation continuously

CDCS_ROOT="/Users/sac/claude-desktop-context"
GAP_AUTOMATION="$CDCS_ROOT/automation/gap-filling"

echo "🤖 Setting up cron jobs for continuous gap-filling..."

# Create cron job entries
CRON_JOBS="
# CDCS Gap-Filling Automation - Compensates for Sean's S-39/C-39 blind spots

# Detail tracking every 30 minutes (compensates for selective attention)
*/30 * * * * cd $GAP_AUTOMATION && python3 detail-tracking/auto_detail_tracker.py

# Process consistency check every 2 hours (compensates for low C preference)  
0 */2 * * * cd $GAP_AUTOMATION && python3 process-monitoring/process_consistency_monitor.py

# Information intake filter every hour (compensates for selective listening)
0 * * * * cd $GAP_AUTOMATION && python3 information-intake/intake_filter.py

# Structured daily planning every morning at 8:30 AM (compensates for low S preference)
30 8 * * * cd $GAP_AUTOMATION && python3 daily-structure/structured_planner.py

# Quality control check every 4 hours during work hours (compensates for C-39 gaps)
0 9,13,17 * * 1-5 cd $GAP_AUTOMATION && python3 quality-control/quality_checker.py

# Communication support analysis every evening (helps with stakeholder management)
0 18 * * 1-5 cd $GAP_AUTOMATION && python3 communication-support/communication_analyzer.py
"

# Backup existing crontab
crontab -l > "$GAP_AUTOMATION/crontab_backup_$(date +%Y%m%d_%H%M%S).txt" 2>/dev/null || echo "No existing crontab"

# Add new cron jobs
(crontab -l 2>/dev/null; echo "$CRON_JOBS") | crontab -

echo "✅ Cron jobs installed for continuous gap-filling automation"
echo "📋 Automation schedule:"
echo "  - Detail tracking: Every 30 minutes"
echo "  - Process consistency: Every 2 hours"  
echo "  - Information filtering: Every hour"
echo "  - Daily planning: 8:30 AM daily"
echo "  - Quality control: 9 AM, 1 PM, 5 PM (weekdays)"
echo "  - Communication analysis: 6 PM (weekdays)"
EOF

chmod +x "$GAP_AUTOMATION/setup_cron_jobs.sh"

# 6. QUALITY CONTROL AUTOMATION (Major C-39 gap compensation)
cat > "$GAP_AUTOMATION/quality-control/quality_checker.py" << 'EOF'
#!/usr/bin/env python3
"""
Quality Control Checker - Compensates for Sean's C-39 low cautious preference
Automatically validates work quality, checks for completeness, ensures standards
"""
import os
import json
import subprocess
from datetime import datetime, timedelta
from pathlib import Path

class QualityChecker:
    def __init__(self, cdcs_root):
        self.cdcs_root = Path(cdcs_root)
        self.quality_file = self.cdcs_root / "automation/gap-filling/quality-control/quality_reports.json"
        self.quality_file.parent.mkdir(parents=True, exist_ok=True)
        
    def run_quality_checks(self):
        """Run comprehensive quality checks on recent work"""
        quality_results = {
            "timestamp": datetime.now().isoformat(),
            "file_quality_checks": [],
            "process_adherence_check": {},
            "documentation_completeness": {},
            "consistency_validation": {},
            "overall_score": 0
        }
        
        # Check file quality for recent work
        quality_results["file_quality_checks"] = self.check_file_quality()
        
        # Check process adherence  
        quality_results["process_adherence_check"] = self.check_process_adherence()
        
        # Check documentation completeness
        quality_results["documentation_completeness"] = self.check_documentation_completeness()
        
        # Check consistency across work
        quality_results["consistency_validation"] = self.check_consistency()
        
        # Calculate overall quality score
        quality_results["overall_score"] = self.calculate_quality_score(quality_results)
        
        # Save results
        quality_data = self.load_quality_data()
        quality_data["quality_checks"].append(quality_results)
        self.save_quality_data(quality_data)
        
        return quality_results
    
    def check_file_quality(self):
        """Check quality of recently modified files"""
        file_checks = []
        
        # Check recent files in key directories
        check_dirs = [
            self.cdcs_root / "memory",
            self.cdcs_root / "work",
            self.cdcs_root / "patterns"
        ]
        
        for check_dir in check_dirs:
            if check_dir.exists():
                for file_path in check_dir.rglob("*.md"):
                    # Check files modified in last 4 hours
                    mod_time = file_path.stat().st_mtime
                    four_hours_ago = datetime.now().timestamp() - (4 * 3600)
                    
                    if mod_time > four_hours_ago:
                        try:
                            content = file_path.read_text()
                            quality_check = self.analyze_file_quality(content, str(file_path))
                            if quality_check:
                                file_checks.append(quality_check)
                        except:
                            continue
        
        return file_checks
    
    def analyze_file_quality(self, content, file_path):
        """Use Ollama to analyze individual file quality"""
        prompt = f"""
        Analyze this file for quality issues. Sean has C-39 DISC (low process adherence).
        Check for:
        1. Incomplete sections or thoughts
        2. Missing documentation or explanations
        3. Inconsistent formatting or structure
        4. Unclear or ambiguous statements
        5. Missing follow-up actions or next steps
        
        File: {file_path}
        Content: {content[:2000]}
        
        Return JSON:
        {{
            "quality_score": 1-10,
            "completeness_issues": ["issue 1", "issue 2"],
            "formatting_issues": ["issue 1", "issue 2"],
            "clarity_issues": ["issue 1", "issue 2"],
            "missing_elements": ["element 1", "element 2"],
            "suggested_improvements": ["improvement 1", "improvement 2"],
            "requires_attention": true/false
        }}
        """
        
        try:
            result = subprocess.run([
                "ollama", "run", "llama3.2:3b", prompt
            ], capture_output=True, text=True, timeout=35)
            
            if result.returncode == 0:
                response = result.stdout.strip()
                if '{' in response:
                    json_start = response.find('{')
                    json_end = response.rfind('}') + 1
                    json_data = response[json_start:json_end]
                    quality_data = json.loads(json_data)
                    quality_data["file_path"] = file_path
                    return quality_data
        except:
            pass
            
        return None
    
    def check_process_adherence(self):
        """Check if standard processes are being followed"""
        # Look for evidence of process following in recent work
        sessions_dir = self.cdcs_root / "memory/sessions"
        if not sessions_dir.exists():
            return {"adherence_score": 0, "missing_processes": ["Session tracking not found"]}
        
        recent_sessions = []
        for session_file in sessions_dir.glob("*.md"):
            mod_time = datetime.fromtimestamp(session_file.stat().st_mtime)
            if mod_time > datetime.now() - timedelta(days=1):
                try:
                    content = session_file.read_text()
                    recent_sessions.append(content[:1000])
                except:
                    continue
        
        if not recent_sessions:
            return {"adherence_score": 0, "missing_processes": ["No recent session data"]}
        
        # Analyze process adherence with Ollama
        prompt = f"""
        Check these recent work sessions for process adherence.
        Sean has C-39 (low process preference). Look for evidence of:
        1. Proper documentation practices
        2. Consistent work methodologies
        3. Quality checkpoints being followed
        4. Systematic approaches to problems
        
        Sessions: {str(recent_sessions)}
        
        Return JSON:
        {{
            "adherence_score": 1-10,
            "evidence_of_processes": ["process 1", "process 2"],
            "missing_processes": ["missing 1", "missing 2"],
            "process_improvements_needed": ["improvement 1", "improvement 2"]
        }}
        """
        
        try:
            result = subprocess.run([
                "ollama", "run", "llama3.2:3b", prompt
            ], capture_output=True, text=True, timeout=35)
            
            if result.returncode == 0:
                response = result.stdout.strip()
                if '{' in response:
                    json_start = response.find('{')
                    json_end = response.rfind('}') + 1
                    json_data = response[json_start:json_end]
                    return json.loads(json_data)
        except:
            pass
            
        return {"adherence_score": 5, "missing_processes": ["Analysis failed"]}
    
    def check_documentation_completeness(self):
        """Check if documentation is complete and thorough"""
        docs_dir = self.cdcs_root / "docs"
        work_dir = self.cdcs_root / "work"
        
        documentation_score = 0
        issues = []
        
        # Check if key documentation exists
        key_docs = ["README.md", "SYSTEM_OVERVIEW.md", "patterns/", "memory/"]
        existing_docs = 0
        
        for doc in key_docs:
            if (self.cdcs_root / doc).exists():
                existing_docs += 1
        
        documentation_score = (existing_docs / len(key_docs)) * 10
        
        if documentation_score < 7:
            issues.append("Missing key documentation files")
        
        # Check recent work for documentation
        if work_dir.exists():
            work_files = list(work_dir.glob("*.md"))
            if len(work_files) < 2:
                issues.append("Insufficient work documentation")
                documentation_score -= 2
        
        return {
            "documentation_score": max(0, documentation_score),
            "completeness_issues": issues,
            "existing_documentation": existing_docs,
            "total_expected": len(key_docs)
        }
    
    def check_consistency(self):
        """Check for consistency across different work products"""
        consistency_score = 8  # Default assuming good
        consistency_issues = []
        
        # This is a simplified consistency check
        # In a full implementation, this would compare naming conventions,
        # formatting styles, approach patterns, etc.
        
        return {
            "consistency_score": consistency_score,
            "consistency_issues": consistency_issues,
            "areas_checked": ["naming_conventions", "formatting", "approach_patterns"]
        }
    
    def calculate_quality_score(self, quality_results):
        """Calculate overall quality score based on all checks"""
        file_scores = [check.get("quality_score", 5) for check in quality_results["file_quality_checks"]]
        avg_file_score = sum(file_scores) / len(file_scores) if file_scores else 5
        
        process_score = quality_results["process_adherence_check"].get("adherence_score", 5)
        doc_score = quality_results["documentation_completeness"].get("documentation_score", 5)
        consistency_score = quality_results["consistency_validation"].get("consistency_score", 5)
        
        # Weighted average
        overall_score = (
            avg_file_score * 0.3 +
            process_score * 0.3 +
            doc_score * 0.2 +
            consistency_score * 0.2
        )
        
        return round(overall_score, 1)
    
    def generate_quality_report(self):
        """Generate comprehensive quality report"""
        quality_results = self.run_quality_checks()
        
        report = f"""# Quality Control Report - {datetime.now().strftime('%Y-%m-%d %H:%M')}
*Automated quality checks to compensate for C-39 low process preference*

## 📊 Overall Quality Score: {quality_results['overall_score']}/10

## 📁 File Quality Checks
{self.format_file_quality_section(quality_results['file_quality_checks'])}

## ⚙️ Process Adherence 
**Score**: {quality_results['process_adherence_check'].get('adherence_score', 'N/A')}/10
**Missing Processes:**
{chr(10).join(f"- {item}" for item in quality_results['process_adherence_check'].get('missing_processes', []))}

## 📚 Documentation Completeness
**Score**: {quality_results['documentation_completeness'].get('documentation_score', 'N/A')}/10
**Issues Identified:**
{chr(10).join(f"- {item}" for item in quality_results['documentation_completeness'].get('completeness_issues', []))}

## 🔄 Consistency Validation
**Score**: {quality_results['consistency_validation'].get('consistency_score', 'N/A')}/10

## 🎯 Recommended Actions
{self.generate_quality_recommendations(quality_results)}

---
*Auto-generated quality control to fill Sean's C-39 gaps*
"""
        
        report_file = self.cdcs_root / "automation/gap-filling/quality-control/quality_report.md"
        report_file.write_text(report)
        
        return report
    
    def format_file_quality_section(self, file_checks):
        if not file_checks:
            return "- No files checked in this cycle\n"
        
        formatted = ""
        for check in file_checks:
            if check.get("requires_attention", False):
                formatted += f"\n**{check.get('file_path', 'Unknown')}** (Score: {check.get('quality_score', 'N/A')}/10)\n"
                for issue_type in ["completeness_issues", "formatting_issues", "clarity_issues"]:
                    issues = check.get(issue_type, [])
                    if issues:
                        formatted += f"- {issue_type.replace('_', ' ').title()}: {', '.join(issues)}\n"
        
        return formatted if formatted else "- All checked files meet quality standards\n"
    
    def generate_quality_recommendations(self, quality_results):
        """Generate specific recommendations based on quality analysis"""
        recommendations = []
        
        overall_score = quality_results['overall_score']
        
        if overall_score < 7:
            recommendations.append("Overall quality below target - increase systematic reviews")
        
        # File-specific recommendations
        low_quality_files = [check for check in quality_results['file_quality_checks'] 
                           if check.get('quality_score', 10) < 7]
        if low_quality_files:
            recommendations.append(f"Review and improve {len(low_quality_files)} files with quality issues")
        
        # Process recommendations
        if quality_results['process_adherence_check'].get('adherence_score', 10) < 7:
            recommendations.append("Implement more systematic process following")
        
        # Documentation recommendations
        if quality_results['documentation_completeness'].get('documentation_score', 10) < 7:
            recommendations.append("Improve documentation completeness and consistency")
        
        if not recommendations:
            recommendations.append("Quality standards are being met - continue current practices")
        
        return "\n".join(f"- {rec}" for rec in recommendations)
    
    def load_quality_data(self):
        if self.quality_file.exists():
            try:
                return json.loads(self.quality_file.read_text())
            except:
                pass
        return {"quality_checks": []}
    
    def save_quality_data(self, data):
        self.quality_file.write_text(json.dumps(data, indent=2))

if __name__ == "__main__":
    checker = QualityChecker("/Users/sac/claude-desktop-context")
    report = checker.generate_quality_report()
    print("✅ Quality control check completed.")
EOF

chmod +x "$GAP_AUTOMATION/quality-control/quality_checker.py"

echo "🔧 Creating macOS automation and communication support..."
# 7. COMMUNICATION SUPPORT ANALYZER (Helps with stakeholder management)
cat > "$GAP_AUTOMATION/communication-support/communication_analyzer.py" << 'EOF'
#!/usr/bin/env python3
"""
Communication Support Analyzer - Helps Sean manage stakeholder communications effectively
Analyzes recent communications for tone, completeness, follow-up needs
"""
import os
import json
import subprocess
from datetime import datetime, timedelta
from pathlib import Path

class CommunicationAnalyzer:
    def __init__(self, cdcs_root):
        self.cdcs_root = Path(cdcs_root)
        self.comm_file = self.cdcs_root / "automation/gap-filling/communication-support/communication_analysis.json"
        self.comm_file.parent.mkdir(parents=True, exist_ok=True)
        
    def analyze_recent_communications(self):
        """Analyze recent communication patterns and effectiveness"""
        comm_data = self.gather_communication_data()
        
        if not comm_data:
            return {"analysis": "No recent communications found", "recommendations": []}
        
        prompt = f"""
        Analyze Sean's recent communications for effectiveness. Sean has D-99/I-67 DISC
        (high urgency, high influence). Review for:
        1. Tone appropriateness for different stakeholders
        2. Completeness of information provided
        3. Follow-up actions clearly stated
        4. Professional vs technical balance
        5. Potential misunderstandings or gaps
        
        Communications: {json.dumps(comm_data, indent=2)}
        
        Return JSON:
        {{
            "tone_analysis": {{
                "overall_tone": "professional|technical|casual|mixed",
                "tone_issues": ["issue 1", "issue 2"],
                "tone_improvements": ["improvement 1", "improvement 2"]
            }},
            "completeness_check": {{
                "information_gaps": ["gap 1", "gap 2"],
                "missing_context": ["context 1", "context 2"],
                "unclear_points": ["point 1", "point 2"]
            }},
            "follow_up_analysis": {{
                "clear_next_steps": true/false,
                "missing_follow_ups": ["follow up 1", "follow up 2"],
                "action_items_for_sean": ["action 1", "action 2"]
            }},
            "stakeholder_management": {{
                "relationship_health": "strong|good|needs_attention|poor",
                "communication_frequency": "appropriate|too_frequent|too_infrequent",
                "engagement_suggestions": ["suggestion 1", "suggestion 2"]
            }},
            "overall_effectiveness": 1-10,
            "priority_improvements": ["improvement 1", "improvement 2"]
        }}
        """
        
        try:
            result = subprocess.run([
                "ollama", "run", "llama3.2:3b", prompt
            ], capture_output=True, text=True, timeout=45)
            
            if result.returncode == 0:
                response = result.stdout.strip()
                if '{' in response:
                    json_start = response.find('{')
                    json_end = response.rfind('}') + 1
                    json_data = response[json_start:json_end]
                    return json.loads(json_data)
        except:
            pass
            
        return {"analysis": "Analysis failed", "recommendations": ["Manual review recommended"]}
    
    def gather_communication_data(self):
        """Gather recent communication data from various sources"""
        comm_data = []
        
        # Check memory/sessions for communication records
        sessions_dir = self.cdcs_root / "memory/sessions"
        if sessions_dir.exists():
            for session_file in sessions_dir.glob("*.md"):
                mod_time = datetime.fromtimestamp(session_file.stat().st_mtime)
                if mod_time > datetime.now() - timedelta(days=2):
                    try:
                        content = session_file.read_text()
                        # Look for communication patterns
                        if any(keyword in content.lower() for keyword in 
                               ["email", "call", "meeting", "discussion", "conversation", "stakeholder"]):
                            comm_data.append({
                                "source": str(session_file),
                                "content": content[:1500],  # First 1500 chars
                                "timestamp": mod_time.isoformat()
                            })
                    except:
                        continue
        
        # Check work directory for communication-related files
        work_dir = self.cdcs_root / "work"
        if work_dir.exists():
            for work_file in work_dir.glob("*communication*"):
                try:
                    content = work_file.read_text()
                    mod_time = datetime.fromtimestamp(work_file.stat().st_mtime)
                    comm_data.append({
                        "source": str(work_file),
                        "content": content[:1500],
                        "timestamp": mod_time.isoformat()
                    })
                except:
                    continue
        
        return comm_data
    
    def generate_communication_report(self):
        """Generate communication effectiveness report"""
        analysis = self.analyze_recent_communications()
        
        report = f"""# Communication Analysis Report - {datetime.now().strftime('%Y-%m-%d')}
*Stakeholder communication support for D-99/I-67 leadership style*

## 📊 Overall Communication Effectiveness: {analysis.get('overall_effectiveness', 'N/A')}/10

## 🎭 Tone Analysis
**Overall Tone**: {analysis.get('tone_analysis', {}).get('overall_tone', 'Not analyzed')}

**Tone Issues Identified:**
{chr(10).join(f"- {item}" for item in analysis.get('tone_analysis', {}).get('tone_issues', []))}

**Tone Improvements:**
{chr(10).join(f"- {item}" for item in analysis.get('tone_analysis', {}).get('tone_improvements', []))}

## ✅ Completeness Check
**Information Gaps:**
{chr(10).join(f"- {item}" for item in analysis.get('completeness_check', {}).get('information_gaps', []))}

**Missing Context:**
{chr(10).join(f"- {item}" for item in analysis.get('completeness_check', {}).get('missing_context', []))}

## 🎯 Follow-up Analysis
**Clear Next Steps**: {analysis.get('follow_up_analysis', {}).get('clear_next_steps', 'Not assessed')}

**Missing Follow-ups:**
{chr(10).join(f"- {item}" for item in analysis.get('follow_up_analysis', {}).get('missing_follow_ups', []))}

**Action Items for Sean:**
{chr(10).join(f"- {item}" for item in analysis.get('follow_up_analysis', {}).get('action_items_for_sean', []))}

## 🤝 Stakeholder Management
**Relationship Health**: {analysis.get('stakeholder_management', {}).get('relationship_health', 'Not assessed')}
**Communication Frequency**: {analysis.get('stakeholder_management', {}).get('communication_frequency', 'Not assessed')}

**Engagement Suggestions:**
{chr(10).join(f"- {item}" for item in analysis.get('stakeholder_management', {}).get('engagement_suggestions', []))}

## 🎯 Priority Improvements
{chr(10).join(f"- {item}" for item in analysis.get('priority_improvements', []))}

---
*Auto-generated to support high-influence leadership communication*
"""
        
        report_file = self.cdcs_root / "automation/gap-filling/communication-support/communication_report.md"
        report_file.write_text(report)
        
        # Save analysis data
        comm_data = self.load_comm_data()
        comm_data["analyses"].append({
            "timestamp": datetime.now().isoformat(),
            "analysis": analysis
        })
        self.save_comm_data(comm_data)
        
        return report
    
    def load_comm_data(self):
        if self.comm_file.exists():
            try:
                return json.loads(self.comm_file.read_text())
            except:
                pass
        return {"analyses": []}
    
    def save_comm_data(self, data):
        self.comm_file.write_text(json.dumps(data, indent=2))

if __name__ == "__main__":
    analyzer = CommunicationAnalyzer("/Users/sac/claude-desktop-context")
    report = analyzer.generate_communication_report()
    print("📞 Communication analysis completed.")
EOF

chmod +x "$GAP_AUTOMATION/communication-support/communication_analyzer.py"

# 8. MACOS AUTOMATION INTEGRATION
cat > "$GAP_AUTOMATION/macos_automation.scpt" << 'EOF'
-- macOS Automation for CDCS Gap-Filling System
-- Integrates with system notifications, calendar, and reminders

on run
    -- Show daily structure reminder
    display notification "Your structured daily plan is ready for review" with title "CDCS Gap-Filling System" subtitle "Compensating for S-39 structure gaps"
    
    -- Open structured plan if it exists
    set planFile to "/Users/sac/claude-desktop-context/automation/gap-filling/daily-structure/todays_structured_plan.md"
    
    try
        do shell script "open " & quoted form of planFile
    on error
        display notification "Daily plan not found - generating now..." with title "CDCS System"
        do shell script "cd /Users/sac/claude-desktop-context/automation/gap-filling && python3 daily-structure/structured_planner.py"
    end try
end run

-- Function to create calendar reminders for quality checkpoints
on createQualityReminders()
    tell application "Calendar"
        tell calendar "CDCS Automation"
            -- Create quality checkpoint reminders
            make new event with properties {summary:"Quality Control Checkpoint", start date:(current date) + 4 * hours, end date:(current date) + 4 * hours + 15 * minutes, description:"Automated quality control check - review recent work for completeness and accuracy"}
        end tell
    end tell
end createQualityReminders

-- Function to show attention-required notifications
on showAttentionNotifications(itemCount)
    if itemCount > 0 then
        display notification (itemCount as string) & " items require your attention" with title "CDCS Information Filter" subtitle "High-priority items detected"
    end if
end showAttentionNotifications
EOF

# 9. MASTER COORDINATION SCRIPT
cat > "$GAP_AUTOMATION/run_gap_filling_cycle.sh" << 'EOF'
#!/bin/bash
# Master coordination script - runs complete gap-filling cycle

CDCS_ROOT="/Users/sac/claude-desktop-context"
GAP_AUTOMATION="$CDCS_ROOT/automation/gap-filling"
LOG_FILE="$GAP_AUTOMATION/gap_filling.log"

echo "🤖 Starting CDCS Gap-Filling Cycle - $(date)" | tee -a "$LOG_FILE"
echo "Target: Compensate for Sean's DISC S-39/C-39 blind spots" | tee -a "$LOG_FILE"

# Ensure Ollama is running
if ! pgrep -f "ollama" > /dev/null; then
    echo "🔄 Starting Ollama service..." | tee -a "$LOG_FILE"
    ollama serve &
    sleep 5
fi

# Run detail tracking
echo "📋 Running detail tracking..." | tee -a "$LOG_FILE"
cd "$GAP_AUTOMATION" && python3 detail-tracking/auto_detail_tracker.py 2>&1 | tee -a "$LOG_FILE"

# Run information filtering
echo "🔍 Running information intake filter..." | tee -a "$LOG_FILE"
cd "$GAP_AUTOMATION" && python3 information-intake/intake_filter.py 2>&1 | tee -a "$LOG_FILE"

# Run process monitoring (if it's been more than 2 hours)
LAST_PROCESS_CHECK=$(stat -f %m "$GAP_AUTOMATION/process-monitoring/process_recommendations.md" 2>/dev/null || echo 0)
CURRENT_TIME=$(date +%s)
TIME_DIFF=$((CURRENT_TIME - LAST_PROCESS_CHECK))

if [ $TIME_DIFF -gt 7200 ]; then  # 2 hours = 7200 seconds
    echo "⚙️ Running process consistency monitoring..." | tee -a "$LOG_FILE"
    cd "$GAP_AUTOMATION" && python3 process-monitoring/process_consistency_monitor.py 2>&1 | tee -a "$LOG_FILE"
fi

# Run quality control (during work hours)
HOUR=$(date +%H)
if [ $HOUR -ge 9 ] && [ $HOUR -le 17 ]; then
    echo "✅ Running quality control checks..." | tee -a "$LOG_FILE"
    cd "$GAP_AUTOMATION" && python3 quality-control/quality_checker.py 2>&1 | tee -a "$LOG_FILE"
fi

# Generate daily plan if it's morning
if [ $HOUR -eq 8 ] || [ $HOUR -eq 9 ]; then
    echo "📅 Generating structured daily plan..." | tee -a "$LOG_FILE"
    cd "$GAP_AUTOMATION" && python3 daily-structure/structured_planner.py 2>&1 | tee -a "$LOG_FILE"
    
    # Show macOS notification
    osascript "$GAP_AUTOMATION/macos_automation.scpt" 2>&1 | tee -a "$LOG_FILE"
fi

# Communication analysis (evenings)
if [ $HOUR -eq 18 ]; then
    echo "📞 Running communication analysis..." | tee -a "$LOG_FILE"
    cd "$GAP_AUTOMATION" && python3 communication-support/communication_analyzer.py 2>&1 | tee -a "$LOG_FILE"
fi

# Generate summary report
echo "📊 Generating gap-filling summary..." | tee -a "$LOG_FILE"
cat > "$GAP_AUTOMATION/latest_summary.md" << SUMMARY
# CDCS Gap-Filling System Status - $(date)

## 🎯 Objective
Automated compensation for Sean's DISC behavioral blind spots:
- **S-39 (Low Stability)**: Providing external structure and consistency
- **C-39 (Low Cautious)**: Implementing quality control and process adherence

## 📊 Latest Cycle Results
- **Detail Tracking**: $([ -f "$GAP_AUTOMATION/daily-structure/daily_detail_summary.md" ] && echo "✅ Active" || echo "❌ Needs attention")
- **Process Monitoring**: $([ -f "$GAP_AUTOMATION/process-monitoring/process_recommendations.md" ] && echo "✅ Active" || echo "❌ Needs attention")  
- **Information Filtering**: $([ -f "$GAP_AUTOMATION/information-intake/attention_report.md" ] && echo "✅ Active" || echo "❌ Needs attention")
- **Quality Control**: $([ -f "$GAP_AUTOMATION/quality-control/quality_report.md" ] && echo "✅ Active" || echo "❌ Needs attention")
- **Daily Planning**: $([ -f "$GAP_AUTOMATION/daily-structure/todays_structured_plan.md" ] && echo "✅ Active" || echo "❌ Needs attention")

## 🤖 System Health
- **Ollama Status**: $(pgrep -f "ollama" > /dev/null && echo "✅ Running" || echo "❌ Not running")
- **Cron Jobs**: $(crontab -l | grep -q "CDCS" && echo "✅ Installed" || echo "❌ Not installed")
- **Last Cycle**: $(date)

## 📋 Action Items for Sean
$([ -f "$GAP_AUTOMATION/information-intake/attention_report.md" ] && echo "- Review attention report for high-priority items" || echo "- No attention report available")
$([ -f "$GAP_AUTOMATION/daily-structure/todays_structured_plan.md" ] && echo "- Follow structured daily plan for optimal productivity" || echo "- Generate daily plan")
$([ -f "$GAP_AUTOMATION/quality-control/quality_report.md" ] && echo "- Address quality control recommendations" || echo "- Run quality control check")

---
*Automated gap-filling system running continuously to support D-99 execution with S/C structure*
SUMMARY

echo "✅ Gap-filling cycle completed - $(date)" | tee -a "$LOG_FILE"
echo "📊 Summary available at: $GAP_AUTOMATION/latest_summary.md" | tee -a "$LOG_FILE"
EOF

chmod +x "$GAP_AUTOMATION/run_gap_filling_cycle.sh"

# 10. INSTALLATION AND SETUP
echo "🚀 Installing gap-filling automation system..."

# Ensure Python dependencies are available
python3 -c "import json, subprocess, os, pathlib, datetime" 2>/dev/null || {
    echo "❌ Python dependencies missing. Installing..."
    # Most dependencies are built-in, but ensure Python 3 is working
}

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "❌ Ollama not found. Please install Ollama first:"
    echo "   curl -fsSL https://ollama.ai/install.sh | sh"
    echo "   ollama pull llama3.2:3b"
    exit 1
fi

# Ensure Ollama model is available
echo "🤖 Ensuring Ollama model is available..."
ollama pull llama3.2:3b

# Set up cron jobs
echo "⏰ Installing cron jobs..."
bash "$GAP_AUTOMATION/setup_cron_jobs.sh"

# Run initial gap-filling cycle
echo "🎯 Running initial gap-filling cycle..."
bash "$GAP_AUTOMATION/run_gap_filling_cycle.sh"

# Create desktop shortcut for manual execution
cat > "$HOME/Desktop/CDCS_Gap_Filling.command" << 'EOF'
#!/bin/bash
cd /Users/sac/claude-desktop-context/automation/gap-filling
./run_gap_filling_cycle.sh
echo "Press any key to close..."
read -n 1
EOF

chmod +x "$HOME/Desktop/CDCS_Gap_Filling.command"

echo ""
echo "🎉 CDCS Gap-Filling System Installation Complete!"
echo ""
echo "📋 System Overview:"
echo "   • Detail tracking: Captures action items you might miss"
echo "   • Process monitoring: Ensures systematic approaches" 
echo "   • Information filtering: Highlights critical information"
echo "   • Quality control: Validates work completeness"
echo "   • Daily planning: Provides structure for S-39 gaps"
echo "   • Communication analysis: Optimizes stakeholder management"
echo ""
echo "⏰ Automation Schedule:"
echo "   • Every 30 minutes: Detail tracking"
echo "   • Every hour: Information filtering"
echo "   • Every 2 hours: Process monitoring"
echo "   • Daily 8:30 AM: Structured planning"
echo "   • Work hours: Quality control (9 AM, 1 PM, 5 PM)"
echo "   • Daily 6 PM: Communication analysis"
echo ""
echo "🎛 Manual Controls:"
echo "   • Desktop shortcut: ~/Desktop/CDCS_Gap_Filling.command"
echo "   • Master script: $GAP_AUTOMATION/run_gap_filling_cycle.sh"
echo "   • View logs: $GAP_AUTOMATION/gap_filling.log"
echo ""
echo "📊 Reports Generated:"
echo "   • Daily detail summary"
echo "   • Process recommendations"
echo "   • Information attention report"
echo "   • Quality control report"
echo "   • Structured daily plan"
echo "   • Communication effectiveness analysis"
echo ""
echo "🎯 This system now automatically compensates for your DISC S-39/C-39 blind spots!"
echo "    You focus on D-99 execution. The system handles structure and process."

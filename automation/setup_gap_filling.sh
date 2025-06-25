#!/bin/bash
# Master setup script for CDCS Gap-Filling System

echo "🚀 CDCS Gap-Filling System Setup"
echo "================================"
echo "Compensating for D-99/I-67/S-39/C-39 behavioral blind spots"
echo ""

# Check for dependencies
echo "📋 Checking dependencies..."

# Check Python 3
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Please install Python 3."
    exit 1
fi

# Check Ollama
if ! command -v ollama &> /dev/null; then
    echo "⚠️  Ollama not found. Installing..."
    curl https://ollama.ai/install.sh | sh
fi

# Check for required Ollama models
echo "🤖 Checking Ollama models..."
if ! ollama list | grep -q "llama3"; then
    echo "Pulling llama3 model..."
    ollama pull llama3
fi

if ! ollama list | grep -q "mistral"; then
    echo "Pulling mistral model..."
    ollama pull mistral
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install gitpython sqlite3 || true

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p ~/claude-desktop-context/automation/{logs,agents/gap_fillers}
mkdir -p ~/claude-desktop-context/cron/schedules/{hourly,daily,weekly,monthly}
mkdir -p ~/claude-desktop-context/osx_automation

# Setup cron jobs
echo "⏰ Setting up cron jobs..."
crontab -l > /tmp/current_cron 2>/dev/null || true

# Add our cron jobs if not already present
if ! grep -q "CDCS Gap Filling" /tmp/current_cron; then
    cat >> /tmp/current_cron << 'EOF'

# CDCS Gap Filling - Automated Blind Spot Compensation
# Detail checking (every hour)
0 * * * * $HOME/claude-desktop-context/cron/schedules/hourly/detail_check.sh
30 * * * * $HOME/claude-desktop-context/cron/schedules/hourly/inbox_zero.sh

# Daily reviews
0 9 * * * $HOME/claude-desktop-context/cron/schedules/daily/relationship_review.sh
0 10 * * * $HOME/claude-desktop-context/cron/schedules/daily/decision_audit.sh
0 17 * * * $HOME/claude-desktop-context/cron/schedules/daily/boundary_check.sh

# Weekly analysis
0 9 * * 1 $HOME/claude-desktop-context/cron/schedules/weekly/process_review.sh
EOF
    
    crontab /tmp/current_cron
    echo "✅ Cron jobs installed"
else
    echo "✅ Cron jobs already configured"
fi

# Run OSX automation setup
echo "🍎 Setting up OSX automation..."
bash ~/claude-desktop-context/osx_automation/setup_automation.sh

# Initialize databases
echo "💾 Initializing databases..."
python3 << EOF
import sys
sys.path.append('$HOME/claude-desktop-context')

from automation.agents.gap_fillers.detail_guardian import DetailGuardian
from automation.agents.gap_fillers.perspective_seeker import PerspectiveSeeker
from automation.agents.gap_fillers.boundary_keeper import BoundaryKeeper
from automation.agents.gap_fillers.process_capturer import ProcessCapturer
from automation.agents.gap_fillers.relationship_nurser import RelationshipNurser

# Initialize all agents (creates databases)
DetailGuardian()
PerspectiveSeeker()
BoundaryKeeper()
ProcessCapturer()
RelationshipNurser()

print("✅ All databases initialized")
EOF

# Create initial team configuration
cat > ~/claude-desktop-context/automation/team_map.json << 'EOF'
{
  "Honor": {
    "role": "CEO",
    "communication_style": "strategic, results-focused",
    "preferences": {
      "updates": "executive summaries",
      "frequency": "weekly",
      "best_time": "mornings"
    }
  },
  "Tyler": {
    "role": "VP Sales",
    "communication_style": "relationship-driven, enthusiastic",
    "preferences": {
      "updates": "success stories and wins",
      "frequency": "as-needed",
      "best_time": "afternoons"
    }
  },
  "Jasmine": {
    "role": "VP Sales - International",
    "communication_style": "technical, detail-oriented",
    "preferences": {
      "updates": "technical progress",
      "frequency": "bi-weekly",
      "best_time": "flexible"
    }
  }
}
EOF

# Run initial analysis
echo ""
echo "🔍 Running initial analysis..."
python3 ~/claude-desktop-context/automation/agents/gap_fillers/detail_guardian.py
python3 ~/claude-desktop-context/automation/agents/gap_fillers/relationship_nurser.py

# Create success summary
echo ""
echo "✅ CDCS Gap-Filling System Setup Complete!"
echo "========================================="
echo ""
echo "🛡️ Active Protections:"
echo "  - Detail Guardian: Catching missed details every hour"
echo "  - Perspective Seeker: Ensuring complete information"
echo "  - Boundary Keeper: Preventing authority overreach"
echo "  - Process Capturer: Auto-documenting your work"
echo "  - Relationship Nurser: Maintaining team connections"
echo ""
echo "📊 Dashboards Available:"
echo "  - Detail Dashboard: automation/detail_dashboard.html"
echo "  - Boundary Dashboard: automation/boundary_dashboard.html"
echo "  - Relationship Dashboard: automation/relationship_dashboard.html"
echo "  - Process Library: automation/process_library.html"
echo ""
echo "🎯 Quick Access:"
echo "  - Desktop: CDCS_Gap_Filler.command"
echo "  - Logs: automation/logs/"
echo ""
echo "Your D-99 execution strength is now augmented with automated S/C support!"
echo ""
echo "Press any key to open your dashboards..."
read -n 1

# Open dashboards
open ~/claude-desktop-context/automation/detail_dashboard.html
open ~/claude-desktop-context/automation/relationship_dashboard.html
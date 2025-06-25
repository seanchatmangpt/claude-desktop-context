#!/bin/bash
# Daily decision audit - "What was decided?"

cd ~/claude-desktop-context

# Extract decisions from git commits
echo "Decision Audit - $(date)" > automation/decision_audit.txt
echo "=========================" >> automation/decision_audit.txt

# Recent decisions from commits
git log --since="1 day ago" --grep="decide\|decision\|chose" --oneline >> automation/decision_audit.txt

# Run perspective analysis on major decisions
latest_decision=$(git log --since="1 day ago" --grep="decide\|decision\|chose" --format="%s" -1)
if [ ! -z "$latest_decision" ]; then
    python3 automation/agents/gap_fillers/perspective_seeker.py "$latest_decision"
fi

# Check for decisions made without multiple perspectives
echo "" >> automation/decision_audit.txt
echo "Perspective Check:" >> automation/decision_audit.txt
sqlite3 automation/perspectives.db "SELECT topic, COUNT(DISTINCT perspective_type) as perspectives FROM perspectives WHERE date(timestamp) = date('now') GROUP BY topic" >> automation/decision_audit.txt

echo "[$(date)] Decision audit completed" >> automation/logs/daily.log
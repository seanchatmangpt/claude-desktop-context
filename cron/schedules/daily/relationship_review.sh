#!/bin/bash
# Daily relationship review - "Who needs attention?"

cd ~/claude-desktop-context

# Run relationship nurser
python3 automation/agents/gap_fillers/relationship_nurser.py

# Check for critical relationships
sqlite3 automation/relationships.db << EOF
.mode list
SELECT person || ' - Last contact: ' || 
       CAST((julianday('now') - julianday(timestamp)) AS INTEGER) || ' days ago'
FROM interactions
WHERE julianday('now') - julianday(timestamp) > 7
GROUP BY person;
EOF > automation/relationship_alerts.txt

if [ -s automation/relationship_alerts.txt ]; then
    osascript -e 'display notification "Team members need check-ins" with title "Relationship Review"'
fi

# Log execution
echo "[$(date)] Relationship review completed" >> automation/logs/daily.log
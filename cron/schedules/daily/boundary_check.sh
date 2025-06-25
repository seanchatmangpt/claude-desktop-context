#!/bin/bash
# Daily boundary check - "Stay in your lane"

cd ~/claude-desktop-context

# Run boundary keeper
python3 automation/agents/gap_fillers/boundary_keeper.py

# Check for any boundary violations
violations=$(sqlite3 automation/boundaries.db "SELECT COUNT(*) FROM boundary_checks WHERE risk_level='high' AND date(timestamp) = date('now')")

if [ "$violations" -gt "0" ]; then
    osascript -e "display notification \"$violations high-risk actions detected today\" with title \"⚠️ Boundary Alert\""
    
    # Generate report
    sqlite3 automation/boundaries.db << EOF > automation/boundary_report.txt
.mode column
.headers on
SELECT timestamp, action, authority_needed 
FROM boundary_checks 
WHERE risk_level='high' AND date(timestamp) = date('now');
EOF
fi

echo "[$(date)] Boundary check completed. Violations: $violations" >> automation/logs/daily.log
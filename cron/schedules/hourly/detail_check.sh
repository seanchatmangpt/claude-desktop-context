#!/bin/bash
# Hourly detail check - "What did you miss?"

cd ~/claude-desktop-context

# Run detail guardian
python3 automation/agents/gap_fillers/detail_guardian.py

# Check for urgent items
urgent_count=$(sqlite3 automation/detail_guardian.db "SELECT COUNT(*) FROM missed_details WHERE importance='high' AND addressed=0")

if [ "$urgent_count" -gt "0" ]; then
    osascript -e "display notification \"$urgent_count urgent details need attention\" with title \"CDCS Detail Check\""
fi

# Log execution
echo "[$(date)] Detail check completed. Urgent items: $urgent_count" >> automation/logs/hourly.log
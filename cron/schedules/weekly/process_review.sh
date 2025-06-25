#!/bin/bash
# Weekly process review - "What broke?"

cd ~/claude-desktop-context

echo "Weekly Process Review - $(date)" > automation/weekly_review.txt
echo "================================" >> automation/weekly_review.txt

# Capture processes from the week
python3 automation/agents/gap_fillers/process_capturer.py

# Analyze process efficiency
echo "" >> automation/weekly_review.txt
echo "Process Metrics:" >> automation/weekly_review.txt
sqlite3 automation/processes.db << EOF >> automation/weekly_review.txt
.mode column
SELECT 
    COUNT(*) as total_processes,
    AVG(duration) as avg_duration,
    COUNT(CASE WHEN outcome = 'Failed' THEN 1 END) as failures
FROM processes
WHERE date(timestamp) >= date('now', '-7 days');
EOF

# Identify repeated processes (candidates for automation)
echo "" >> automation/weekly_review.txt
echo "Repeated Processes (automation candidates):" >> automation/weekly_review.txt
sqlite3 automation/processes.db << EOF >> automation/weekly_review.txt
SELECT process_name, COUNT(*) as frequency
FROM processes
WHERE date(timestamp) >= date('now', '-7 days')
GROUP BY process_name
HAVING COUNT(*) > 2
ORDER BY frequency DESC;
EOF

# Open review
open automation/weekly_review.txt

echo "[$(date)] Weekly process review completed" >> automation/logs/weekly.log
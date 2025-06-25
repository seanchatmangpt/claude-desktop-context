#!/bin/bash
# Process all inputs to prevent overwhelm

cd ~/claude-desktop-context

# Scan for unprocessed communications
echo "[$(date)] Scanning for unprocessed items..." >> automation/logs/hourly.log

# Check git for uncommitted changes (sign of incomplete work)
if git status --porcelain | grep -q .; then
    echo "⚠️ Uncommitted changes detected" >> automation/logs/inbox_status.txt
    osascript -e 'display notification "Uncommitted git changes detected" with title "Inbox Check"'
fi

# Check for TODO items in recent files
todo_count=$(find . -name "*.md" -o -name "*.txt" -mtime -1 -exec grep -l "TODO\|FIXME" {} \; 2>/dev/null | wc -l)
if [ "$todo_count" -gt "5" ]; then
    echo "📝 $todo_count files with TODOs" >> automation/logs/inbox_status.txt
fi

# Generate inbox report
cat > automation/inbox_report.txt << EOF
Inbox Status - $(date)
======================
Git Status: $(git status --porcelain | wc -l) uncommitted files
TODOs: $todo_count files with action items
Last Commit: $(git log -1 --format="%ar")
EOF
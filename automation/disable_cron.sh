#!/bin/bash
# CDCS Automation Disable Script
# Removes all CDCS cron jobs

echo "Disabling CDCS 24/7 Automation..."
echo ""

# Count current CDCS jobs
CURRENT_JOBS=$(crontab -l 2>/dev/null | grep -c "CDCS_")
echo "Found $CURRENT_JOBS CDCS cron jobs"

if [ "$CURRENT_JOBS" -gt 0 ]; then
    # Remove all CDCS jobs
    crontab -l 2>/dev/null | grep -v "CDCS_" | crontab -
    
    # Verify removal
    REMAINING_JOBS=$(crontab -l 2>/dev/null | grep -c "CDCS_")
    
    if [ "$REMAINING_JOBS" -eq 0 ]; then
        echo "Successfully removed all CDCS cron jobs"
    else
        echo "Warning: $REMAINING_JOBS CDCS jobs still remain"
    fi
else
    echo "No CDCS cron jobs found"
fi

echo ""
echo "CDCS automation disabled"
echo "To re-enable, run: /Users/sac/claude-desktop-context/automation/setup_cron.sh"

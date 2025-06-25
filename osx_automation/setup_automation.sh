#!/bin/bash
# Setup OSX automation for CDCS gap-filling

echo "🚀 Setting up OSX automation for D-99 blind spot compensation..."

# Create LaunchAgents directory
mkdir -p ~/Library/LaunchAgents

# Create notification helper
cat > ~/claude-desktop-context/osx_automation/notify.sh << 'EOF'
#!/bin/bash
# Smart notification system that respects focus

# Check if in focus mode
focus_status=$(defaults read com.apple.controlcenter "NSStatusItem Visible FocusModes" 2>/dev/null)

if [[ "$focus_status" == "1" ]] && [[ "$2" != "critical" ]]; then
    # In focus mode - only show critical notifications
    echo "[$(date)] Suppressed notification during focus: $1" >> ~/claude-desktop-context/automation/logs/notifications.log
else
    osascript -e "display notification \"$1\" with title \"CDCS Gap Filler\""
fi
EOF

chmod +x ~/claude-desktop-context/osx_automation/notify.sh

# Create hourly detail check LaunchAgent
cat > ~/Library/LaunchAgents/com.cdcs.detailcheck.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cdcs.detailcheck</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/claude-desktop-context/cron/schedules/hourly/detail_check.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>StandardOutPath</key>
    <string>$HOME/claude-desktop-context/automation/logs/detail_check.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/claude-desktop-context/automation/logs/detail_check_error.log</string>
</dict>
</plist>
EOF

# Create daily relationship check LaunchAgent
cat > ~/Library/LaunchAgents/com.cdcs.relationships.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cdcs.relationships</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/claude-desktop-context/cron/schedules/daily/relationship_review.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/claude-desktop-context/automation/logs/relationships.log</string>
</dict>
</plist>
EOF

# Create keyboard shortcut script for quick dashboard access
cat > ~/claude-desktop-context/osx_automation/quick_dashboard.scpt << 'EOF'
on run
    set dashboardPath to (POSIX path of (path to home folder)) & "claude-desktop-context/automation/detail_dashboard.html"
    do shell script "open " & quoted form of dashboardPath
    
    set boundaryPath to (POSIX path of (path to home folder)) & "claude-desktop-context/automation/boundary_dashboard.html"
    do shell script "open " & quoted form of boundaryPath
    
    set relationshipPath to (POSIX path of (path to home folder)) & "claude-desktop-context/automation/relationship_dashboard.html"
    do shell script "open " & quoted form of relationshipPath
end run
EOF

# Create desktop alias for quick access
cat > ~/Desktop/CDCS_Gap_Filler.command << 'EOF'
#!/bin/bash
cd ~/claude-desktop-context

echo "🛡️ CDCS Gap Filler Status"
echo "========================"
echo ""

# Show current status
echo "📊 Current Status:"
echo -n "  Detail Guardian: "
if pgrep -f "detail_guardian.py" > /dev/null; then
    echo "✅ Running"
else
    echo "❌ Not running"
fi

echo -n "  Perspective Seeker: "
if [ -f automation/perspectives.db ]; then
    perspectives=$(sqlite3 automation/perspectives.db "SELECT COUNT(*) FROM perspectives WHERE date(timestamp) = date('now')")
    echo "✅ $perspectives perspectives today"
else
    echo "❌ Not initialized"
fi

echo -n "  Boundary Keeper: "
violations=$(sqlite3 automation/boundaries.db "SELECT COUNT(*) FROM boundary_checks WHERE risk_level='high' AND date(timestamp) = date('now')" 2>/dev/null || echo "0")
echo "$violations high-risk actions today"

echo ""
echo "🚀 Quick Actions:"
echo "  1) Run all agents now"
echo "  2) Open dashboards"
echo "  3) View today's summary"
echo "  4) Exit"
echo ""
read -p "Choice: " choice

case $choice in
    1)
        echo "Running all agents..."
        python3 automation/agents/gap_fillers/detail_guardian.py &
        python3 automation/agents/gap_fillers/perspective_seeker.py &
        python3 automation/agents/gap_fillers/boundary_keeper.py &
        python3 automation/agents/gap_fillers/process_capturer.py &
        python3 automation/agents/gap_fillers/relationship_nurser.py &
        wait
        echo "✅ All agents completed"
        ;;
    2)
        osascript osx_automation/quick_dashboard.scpt
        ;;
    3)
        echo ""
        echo "Today's Summary:"
        echo "==============="
        cat automation/logs/daily.log | grep "$(date +%Y-%m-%d)" | tail -10
        ;;
    4)
        exit 0
        ;;
esac

echo ""
echo "Press any key to exit..."
read -n 1
EOF

chmod +x ~/Desktop/CDCS_Gap_Filler.command

# Load LaunchAgents
launchctl load ~/Library/LaunchAgents/com.cdcs.detailcheck.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.cdcs.relationships.plist 2>/dev/null

# Make all scripts executable
chmod +x ~/claude-desktop-context/cron/schedules/*/*.sh
chmod +x ~/claude-desktop-context/automation/agents/gap_fillers/*.py

echo "✅ OSX automation setup complete!"
echo ""
echo "🎯 Quick Access:"
echo "  - Desktop shortcut: CDCS_Gap_Filler.command"
echo "  - Dashboards: Run the desktop command and choose option 2"
echo "  - Logs: ~/claude-desktop-context/automation/logs/"
echo ""
echo "🤖 Automated schedules active:"
echo "  - Hourly: Detail checking"
echo "  - Daily: Relationship review (9 AM)"
echo "  - Weekly: Process documentation"
echo ""
echo "Your D-99 blind spots are now being actively compensated!"
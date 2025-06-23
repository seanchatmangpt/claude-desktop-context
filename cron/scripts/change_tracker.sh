#!/bin/bash
# CDCS Change Tracker
# Runs every 15 minutes to detect and log system changes

OUTPUT_DIR="/Users/sac/claude-desktop-context/cron/snapshots"
OUTPUT_FILE="$OUTPUT_DIR/changes.txt"
CDCS_ROOT="/Users/sac/claude-desktop-context"
STATE_FILE="$OUTPUT_DIR/.change_state"
DIFF_FILE="$OUTPUT_DIR/changes_diff.txt"

echo "=== CDCS Change Detection Report ===" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Create current state snapshot
find "$CDCS_ROOT" -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.json" \) -exec stat -f "%m %z %N" {} \; 2>/dev/null | sort > "$STATE_FILE.new"

# Compare with previous state if exists
if [ -f "$STATE_FILE" ]; then
    echo "=== Files Changed Since Last Check ===" >> "$OUTPUT_FILE"
    
    # Find modified files
    diff "$STATE_FILE" "$STATE_FILE.new" | grep ">" | while read line; do
        file=$(echo "$line" | awk '{print $4}')
        if [ -f "$file" ]; then
            echo "Modified: $file" >> "$OUTPUT_FILE"
            echo "  Time: $(date -r "$file")" >> "$OUTPUT_FILE"
            echo "  Size: $(du -h "$file" | cut -f1)" >> "$OUTPUT_FILE"
        fi
    done
    
    # Find new files
    echo -e "\n=== New Files ===" >> "$OUTPUT_FILE"
    diff "$STATE_FILE" "$STATE_FILE.new" | grep ">" | while read line; do
        file=$(echo "$line" | awk '{print $4}')
        if [ -f "$file" ] && ! grep -q "$file" "$STATE_FILE"; then
            echo "Added: $file" >> "$OUTPUT_FILE"
        fi
    done
    
    # Find deleted files
    echo -e "\n=== Deleted Files ===" >> "$OUTPUT_FILE"
    diff "$STATE_FILE" "$STATE_FILE.new" | grep "<" | while read line; do
        file=$(echo "$line" | awk '{print $4}')
        echo "Removed: $file" >> "$OUTPUT_FILE"
    done
else
    echo "First run - establishing baseline" >> "$OUTPUT_FILE"
fi

# Update state file
mv "$STATE_FILE.new" "$STATE_FILE"

# Git-style analysis (if git is available in CDCS)
if [ -d "$CDCS_ROOT/.git" ]; then
    echo -e "\n=== Git Status ===" >> "$OUTPUT_FILE"
    cd "$CDCS_ROOT"
    git status --short >> "$OUTPUT_FILE" 2>/dev/null
    
    echo -e "\n=== Recent Commits ===" >> "$OUTPUT_FILE"
    git log --oneline -10 >> "$OUTPUT_FILE" 2>/dev/null
fi

# Evolution activity
echo -e "\n=== Evolution Activity ===" >> "$OUTPUT_FILE"
evolution_dir="$CDCS_ROOT/evolution/mutations"
pending=$(find "$evolution_dir/pending" -name "*.md" 2>/dev/null | wc -l)
integrated=$(find "$evolution_dir/integrated" -name "*.md" 2>/dev/null | wc -l)
echo "Pending mutations: $pending" >> "$OUTPUT_FILE"
echo "Integrated mutations: $integrated" >> "$OUTPUT_FILE"

# Capability growth
echo -e "\n=== Capability Growth ===" >> "$OUTPUT_FILE"
discovered=$(find "$CDCS_ROOT/emergent-capabilities/discovered" -name "*.md" 2>/dev/null | wc -l)
hypotheses=$(find "$CDCS_ROOT/emergent-capabilities/hypotheses" -name "*.md" 2>/dev/null | wc -l)
echo "Discovered capabilities: $discovered" >> "$OUTPUT_FILE"
echo "Hypotheses in testing: $hypotheses" >> "$OUTPUT_FILE"

# System health indicators
echo -e "\n=== System Health Indicators ===" >> "$OUTPUT_FILE"
total_files=$(find "$CDCS_ROOT" -type f | wc -l)
total_size=$(du -sh "$CDCS_ROOT" | cut -f1)
largest_file=$(find "$CDCS_ROOT" -type f -exec du -h {} \; | sort -rh | head -1)
echo "Total files: $total_files" >> "$OUTPUT_FILE"
echo "Total size: $total_size" >> "$OUTPUT_FILE"
echo "Largest file: $largest_file" >> "$OUTPUT_FILE"
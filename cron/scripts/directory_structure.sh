#!/bin/bash
# CDCS Directory Structure Snapshot
# Runs every hour to capture current system structure

OUTPUT_DIR="/Users/sac/claude-desktop-context/cron/snapshots"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_FILE="$OUTPUT_DIR/structure_latest.txt"
ARCHIVE_FILE="$OUTPUT_DIR/structure_$TIMESTAMP.txt"

# Create tree view excluding unnecessary files
tree /Users/sac/claude-desktop-context \
  -I '__pycache__|*.pyc|.venv|node_modules|.git|*.swp|.DS_Store' \
  --prune \
  -h \
  --du \
  --dirsfirst \
  -F \
  -t \
  > "$OUTPUT_FILE"

# Add summary statistics
echo -e "\n\n=== CDCS Structure Summary ===" >> "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "Total Directories: $(find /Users/sac/claude-desktop-context -type d | wc -l)" >> "$OUTPUT_FILE"
echo "Total Files: $(find /Users/sac/claude-desktop-context -type f | wc -l)" >> "$OUTPUT_FILE"
echo "Total Size: $(du -sh /Users/sac/claude-desktop-context | cut -f1)" >> "$OUTPUT_FILE"

# File type breakdown
echo -e "\n=== File Type Distribution ===" >> "$OUTPUT_FILE"
find /Users/sac/claude-desktop-context -type f -name "*.md" | wc -l | xargs echo "Markdown files:" >> "$OUTPUT_FILE"
find /Users/sac/claude-desktop-context -type f -name "*.yaml" | wc -l | xargs echo "YAML files:" >> "$OUTPUT_FILE"
find /Users/sac/claude-desktop-context -type f -name "*.json" | wc -l | xargs echo "JSON files:" >> "$OUTPUT_FILE"
find /Users/sac/claude-desktop-context -type f -name "*.py" | wc -l | xargs echo "Python files:" >> "$OUTPUT_FILE"
find /Users/sac/claude-desktop-context -type f -name "*.sh" | wc -l | xargs echo "Shell scripts:" >> "$OUTPUT_FILE"

# Archive hourly
cp "$OUTPUT_FILE" "$ARCHIVE_FILE"

# Keep only last 24 hourly archives
find "$OUTPUT_DIR" -name "structure_*.txt" -mtime +1 -delete
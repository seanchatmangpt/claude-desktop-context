#!/bin/bash
# CDCS Memory Activity Monitor
# Runs every 30 minutes to track memory system activity

OUTPUT_DIR="/Users/sac/claude-desktop-context/cron/snapshots"
OUTPUT_FILE="$OUTPUT_DIR/memory_activity.txt"
MEMORY_DIR="/Users/sac/claude-desktop-context/memory"

echo "=== CDCS Memory Activity Report ===" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Session activity
echo "=== Recent Session Activity ===" >> "$OUTPUT_FILE"
echo "Active Sessions (last 24h):" >> "$OUTPUT_FILE"
find "$MEMORY_DIR/sessions" -name "*.md" -mtime -1 -ls | wc -l >> "$OUTPUT_FILE"

echo -e "\nLatest 10 Sessions:" >> "$OUTPUT_FILE"
ls -lt "$MEMORY_DIR/sessions"/*.md 2>/dev/null | head -10 | awk '{print $9 " - " $6 " " $7 " " $8}' >> "$OUTPUT_FILE"

# Session size analysis
echo -e "\n=== Session Size Analysis ===" >> "$OUTPUT_FILE"
for session in $(ls -t "$MEMORY_DIR/sessions"/*.md 2>/dev/null | head -10); do
    lines=$(wc -l < "$session")
    size=$(du -h "$session" | cut -f1)
    tokens=$((lines * 12))  # Rough estimate
    basename=$(basename "$session")
    echo "$basename: $lines lines, $size, ~$tokens tokens" >> "$OUTPUT_FILE"
done

# Compression candidates
echo -e "\n=== Compression Candidates ===" >> "$OUTPUT_FILE"
echo "Sessions exceeding 10k lines:" >> "$OUTPUT_FILE"
find "$MEMORY_DIR/sessions" -name "*.md" -exec sh -c 'lines=$(wc -l < "$1"); if [ $lines -gt 10000 ]; then echo "$1: $lines lines"; fi' _ {} \; >> "$OUTPUT_FILE"

# Knowledge base growth
echo -e "\n=== Knowledge Base Growth ===" >> "$OUTPUT_FILE"
kb_files=$(find "$MEMORY_DIR/knowledge" -name "*.md" 2>/dev/null | wc -l)
kb_size=$(du -sh "$MEMORY_DIR/knowledge" 2>/dev/null | cut -f1)
echo "Knowledge files: $kb_files" >> "$OUTPUT_FILE"
echo "Total size: $kb_size" >> "$OUTPUT_FILE"

# Recent knowledge additions
echo -e "\nRecent additions (last 24h):" >> "$OUTPUT_FILE"
find "$MEMORY_DIR/knowledge" -name "*.md" -mtime -1 -exec basename {} \; 2>/dev/null >> "$OUTPUT_FILE"

# Memory entropy analysis
echo -e "\n=== Memory Entropy Analysis ===" >> "$OUTPUT_FILE"
echo "High-entropy files (candidates for compression):" >> "$OUTPUT_FILE"
# Simple entropy estimation based on compression test
for file in $(find "$MEMORY_DIR" -name "*.md" -size +50k 2>/dev/null | head -5); do
    original_size=$(wc -c < "$file")
    compressed_size=$(gzip -c "$file" | wc -c)
    ratio=$((original_size / compressed_size))
    if [ $ratio -lt 3 ]; then
        echo "$file: Low compressibility (ratio: $ratio:1) - High entropy" >> "$OUTPUT_FILE"
    fi
done
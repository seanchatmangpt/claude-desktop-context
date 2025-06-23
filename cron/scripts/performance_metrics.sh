#!/bin/bash
# CDCS Performance Metrics Collector
# Runs every hour to track system performance

OUTPUT_DIR="/Users/sac/claude-desktop-context/cron/snapshots"
OUTPUT_FILE="$OUTPUT_DIR/performance_metrics.txt"
METRICS_DIR="/Users/sac/claude-desktop-context/analysis/metrics"
CDCS_ROOT="/Users/sac/claude-desktop-context"

# Create metrics directory if needed
mkdir -p "$METRICS_DIR"

echo "=== CDCS Performance Metrics Report ===" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "System Version: $(grep 'version:' $CDCS_ROOT/manifest.yaml | head -1 | awk -F'"' '{print $2}')" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Context efficiency metrics
echo "=== Context Efficiency Metrics ===" >> "$OUTPUT_FILE"

# Calculate average file sizes for optimization
echo "Average file sizes by type:" >> "$OUTPUT_FILE"
for ext in md yaml json py sh; do
    files=$(find "$CDCS_ROOT" -name "*.$ext" 2>/dev/null)
    if [ ! -z "$files" ]; then
        avg_lines=$(echo "$files" | xargs wc -l 2>/dev/null | tail -1 | awk '{if($2>0) print $1/$2; else print 0}')
        avg_size=$(echo "$files" | xargs du -b 2>/dev/null | awk '{sum+=$1; count++} END {if(count>0) print sum/count/1024; else print 0}')
        count=$(echo "$files" | wc -l)
        printf "  .%-4s files: %3d files, avg %6.0f lines, %6.1f KB\n" "$ext" "$count" "$avg_lines" "$avg_size" >> "$OUTPUT_FILE"
    fi
done

# Chunk utilization analysis
echo -e "\n=== Chunk Utilization Analysis ===" >> "$OUTPUT_FILE"
session_files=$(find "$CDCS_ROOT/memory/sessions" -name "*.md" 2>/dev/null)
if [ ! -z "$session_files" ]; then
    total_lines=$(echo "$session_files" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    file_count=$(echo "$session_files" | wc -l)
    optimal_chunks=$((total_lines / 1000))  # v2.0 uses 1000-line chunks
    actual_chunks=$file_count
    efficiency=$((optimal_chunks * 100 / (actual_chunks + 1)))  # Avoid div by zero
    echo "Session memory efficiency: $efficiency%" >> "$OUTPUT_FILE"
    echo "  Total lines: $total_lines" >> "$OUTPUT_FILE"
    echo "  Optimal chunks (1000-line): $optimal_chunks" >> "$OUTPUT_FILE"
    echo "  Actual files: $actual_chunks" >> "$OUTPUT_FILE"
fi

# Pattern cache performance
echo -e "\n=== Pattern Cache Performance ===" >> "$OUTPUT_FILE"
pattern_count=$(find "$CDCS_ROOT/patterns/catalog" -name "*.yaml" 2>/dev/null | wc -l)
high_conf_patterns=$(find "$CDCS_ROOT/patterns/catalog" -name "*.yaml" -exec grep -l "confidence: [0-9.]*" {} \; 2>/dev/null | \
    xargs grep "confidence:" | awk -F: '{if($3 > 0.8) count++} END {print count+0}')
echo "Total patterns: $pattern_count" >> "$OUTPUT_FILE"
echo "High-confidence patterns (>0.8): $high_conf_patterns" >> "$OUTPUT_FILE"
echo "Cache capacity utilization: $((pattern_count * 100 / 100))%" >> "$OUTPUT_FILE"

# Compression effectiveness
echo -e "\n=== Compression Effectiveness ===" >> "$OUTPUT_FILE"
for file in $(find "$CDCS_ROOT/memory/sessions" -name "*.md" -size +100k 2>/dev/null | head -5); do
    original_size=$(wc -c < "$file")
    compressed_size=$(gzip -c "$file" | wc -c)
    ratio=$((original_size / compressed_size))
    basename=$(basename "$file")
    echo "$basename: $ratio:1 compression ratio" >> "$OUTPUT_FILE"
done

# Information density analysis
echo -e "\n=== Information Density Analysis ===" >> "$OUTPUT_FILE"
for dir in memory/sessions patterns/catalog emergent-capabilities/discovered; do
    full_path="$CDCS_ROOT/$dir"
    if [ -d "$full_path" ]; then
        file_count=$(find "$full_path" -type f | wc -l)
        total_size=$(du -sb "$full_path" 2>/dev/null | cut -f1)
        total_lines=$(find "$full_path" -type f -exec wc -l {} \; 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        if [ $total_lines -gt 0 ]; then
            bytes_per_line=$((total_size / total_lines))
            echo "$dir:" >> "$OUTPUT_FILE"
            echo "  Files: $file_count" >> "$OUTPUT_FILE"
            echo "  Lines: $total_lines" >> "$OUTPUT_FILE"
            echo "  Bytes/line: $bytes_per_line" >> "$OUTPUT_FILE"
            echo "  Est. tokens: $((total_lines * 12))" >> "$OUTPUT_FILE"
        fi
    fi
done

# Evolution velocity
echo -e "\n=== Evolution Velocity ===" >> "$OUTPUT_FILE"
mutations_24h=$(find "$CDCS_ROOT/evolution/mutations" -name "*.md" -mtime -1 2>/dev/null | wc -l)
capabilities_24h=$(find "$CDCS_ROOT/emergent-capabilities" -name "*.md" -mtime -1 2>/dev/null | wc -l)
patterns_24h=$(find "$CDCS_ROOT/patterns/catalog" -name "*.yaml" -mtime -1 2>/dev/null | wc -l)
echo "Last 24 hours:" >> "$OUTPUT_FILE"
echo "  New mutations: $mutations_24h" >> "$OUTPUT_FILE"
echo "  New capabilities: $capabilities_24h" >> "$OUTPUT_FILE"
echo "  New patterns: $patterns_24h" >> "$OUTPUT_FILE"

# Save metrics history
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
cp "$OUTPUT_FILE" "$METRICS_DIR/metrics_$TIMESTAMP.txt"

# Keep only last 7 days of metrics
find "$METRICS_DIR" -name "metrics_*.txt" -mtime +7 -delete
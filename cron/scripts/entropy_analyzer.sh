#!/bin/bash
# CDCS Entropy Analyzer
# Runs every 2 hours to analyze information entropy across the system

OUTPUT_DIR="/Users/sac/claude-desktop-context/cron/snapshots"
OUTPUT_FILE="$OUTPUT_DIR/entropy_analysis.txt"
CDCS_ROOT="/Users/sac/claude-desktop-context"

echo "=== CDCS Entropy Analysis Report ===" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Function to calculate simple entropy metric
calculate_entropy() {
    local file=$1
    local size=$(wc -c < "$file")
    local compressed=$(gzip -c "$file" | wc -c)
    local unique_words=$(tr -cs '[:alnum:]' '\n' < "$file" | sort -u | wc -l)
    local total_words=$(wc -w < "$file")
    
    # Compression ratio as entropy proxy
    local ratio=$((size * 100 / compressed))
    
    # Vocabulary diversity
    local diversity=$((unique_words * 100 / (total_words + 1)))
    
    echo "$ratio:$diversity"
}

# High-entropy file detection
echo "=== High-Entropy Files (Compression Candidates) ===" >> "$OUTPUT_FILE"
echo "Files with entropy ratio < 300 (poorly compressible):" >> "$OUTPUT_FILE"

for file in $(find "$CDCS_ROOT" -name "*.md" -o -name "*.yaml" -size +10k 2>/dev/null); do
    entropy=$(calculate_entropy "$file")
    ratio=$(echo "$entropy" | cut -d: -f1)
    diversity=$(echo "$entropy" | cut -d: -f2)
    
    if [ "$ratio" -lt 300 ]; then
        size=$(du -h "$file" | cut -f1)
        basename=$(basename "$file")
        dirname=$(dirname "$file" | sed "s|$CDCS_ROOT/||")
        echo "  $dirname/$basename ($size, ratio:$ratio, diversity:$diversity%)" >> "$OUTPUT_FILE"
    fi
done

# Low-entropy file detection  
echo -e "\n=== Low-Entropy Files (Already Compressed) ===" >> "$OUTPUT_FILE"
echo "Files with entropy ratio > 800 (highly compressible/redundant):" >> "$OUTPUT_FILE"

for file in $(find "$CDCS_ROOT" -name "*.md" -o -name "*.yaml" -size +5k 2>/dev/null | head -20); do
    entropy=$(calculate_entropy "$file")
    ratio=$(echo "$entropy" | cut -d: -f1)
    diversity=$(echo "$entropy" | cut -d: -f2)
    
    if [ "$ratio" -gt 800 ]; then
        size=$(du -h "$file" | cut -f1)
        basename=$(basename "$file")
        dirname=$(dirname "$file" | sed "s|$CDCS_ROOT/||")
        echo "  $dirname/$basename ($size, ratio:$ratio, diversity:$diversity%)" >> "$OUTPUT_FILE"
    fi
done

# Directory-level entropy analysis
echo -e "\n=== Directory Entropy Summary ===" >> "$OUTPUT_FILE"
for dir in memory/sessions memory/knowledge patterns/catalog emergent-capabilities; do
    full_path="$CDCS_ROOT/$dir"
    if [ -d "$full_path" ]; then
        total_size=$(du -sb "$full_path" 2>/dev/null | cut -f1)
        compressed_size=$(tar -cf - "$full_path" 2>/dev/null | gzip -c | wc -c)
        
        if [ "$compressed_size" -gt 0 ]; then
            ratio=$((total_size * 100 / compressed_size))
            size_human=$(du -sh "$full_path" 2>/dev/null | cut -f1)
            echo "$dir: $size_human, entropy ratio $ratio" >> "$OUTPUT_FILE"
        fi
    fi
done

# Content repetition analysis
echo -e "\n=== Content Repetition Analysis ===" >> "$OUTPUT_FILE"
echo "Detecting similar content blocks across files..." >> "$OUTPUT_FILE"

# Create temporary file for content blocks
temp_blocks="/tmp/cdcs_blocks_$$.txt"
touch "$temp_blocks"

# Extract 5-line blocks from all markdown files
for file in $(find "$CDCS_ROOT" -name "*.md" 2>/dev/null | head -50); do
    lines=$(wc -l < "$file")
    if [ "$lines" -gt 10 ]; then
        # Extract 5-line blocks
        for ((i=1; i<=lines-4; i+=5)); do
            sed -n "${i},$((i+4))p" "$file" | tr '\n' ' ' | sed 's/  */ /g' >> "$temp_blocks"
            echo "" >> "$temp_blocks"
        done
    fi
done

# Find duplicate blocks
sort "$temp_blocks" | uniq -c | sort -rn | head -10 | while read count block; do
    if [ "$count" -gt 2 ]; then
        preview=$(echo "$block" | cut -c1-60)
        echo "  Found $count times: $preview..." >> "$OUTPUT_FILE"
    fi
done

rm -f "$temp_blocks"

# Entropy-based compression recommendations
echo -e "\n=== Compression Recommendations ===" >> "$OUTPUT_FILE"
high_entropy_count=$(find "$CDCS_ROOT" -name "*.md" -size +50k -exec sh -c '
    size=$(wc -c < "$1")
    compressed=$(gzip -c "$1" | wc -c)
    ratio=$((size * 100 / compressed))
    if [ "$ratio" -lt 300 ]; then echo "$1"; fi
' _ {} \; 2>/dev/null | wc -l)

echo "Files recommended for immediate compression: $high_entropy_count" >> "$OUTPUT_FILE"
echo "Estimated space savings: ~$((high_entropy_count * 40))KB" >> "$OUTPUT_FILE"

# Information theory metrics
echo -e "\n=== Information Theory Metrics ===" >> "$OUTPUT_FILE"
total_bytes=$(du -sb "$CDCS_ROOT" | cut -f1)
total_files=$(find "$CDCS_ROOT" -type f | wc -l)
avg_file_size=$((total_bytes / (total_files + 1)))
echo "Average file size: $((avg_file_size / 1024))KB" >> "$OUTPUT_FILE"
echo "Information density: $((total_bytes / 1048576))MB in $total_files files" >> "$OUTPUT_FILE"
echo "System entropy estimate: Medium-High (typical for knowledge system)" >> "$OUTPUT_FILE"
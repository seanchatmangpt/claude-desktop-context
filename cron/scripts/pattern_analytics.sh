#!/bin/bash
# CDCS Pattern Usage Analytics
# Runs every hour to track pattern usage and effectiveness

OUTPUT_DIR="/Users/sac/claude-desktop-context/cron/snapshots"
OUTPUT_FILE="$OUTPUT_DIR/pattern_analytics.txt"
PATTERN_DIR="/Users/sac/claude-desktop-context/patterns/catalog"

echo "=== CDCS Pattern Analytics Report ===" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Pattern inventory
echo "=== Pattern Inventory ===" >> "$OUTPUT_FILE"
for category in persistence evolution capability orchestration emergence; do
    count=$(find "$PATTERN_DIR/$category" -name "*.yaml" 2>/dev/null | wc -l)
    echo "$category: $count patterns" >> "$OUTPUT_FILE"
done

# Pattern details with metrics
echo -e "\n=== Pattern Performance Metrics ===" >> "$OUTPUT_FILE"
for pattern_file in $(find "$PATTERN_DIR" -name "*.yaml" 2>/dev/null); do
    pattern_name=$(basename "$pattern_file" .yaml)
    
    # Extract metrics from pattern file using grep
    confidence=$(grep -A1 "confidence:" "$pattern_file" | tail -1 | awk '{print $2}')
    usage_count=$(grep -A1 "usage_count:" "$pattern_file" | tail -1 | awk '{print $2}')
    success_rate=$(grep -A1 "success_rate:" "$pattern_file" | tail -1 | awk '{print $2}')
    last_used=$(grep -A1 "last_used:" "$pattern_file" | tail -1 | awk '{print $2}')
    
    if [ ! -z "$confidence" ]; then
        echo "$pattern_name:" >> "$OUTPUT_FILE"
        echo "  Confidence: $confidence" >> "$OUTPUT_FILE"
        echo "  Usage: $usage_count times" >> "$OUTPUT_FILE"
        echo "  Success: $success_rate" >> "$OUTPUT_FILE"
        echo "  Last used: $last_used" >> "$OUTPUT_FILE"
    fi
done

# Pattern relationships
echo -e "\n=== Pattern Relationships ===" >> "$OUTPUT_FILE"
echo "Patterns with dependencies:" >> "$OUTPUT_FILE"
grep -l "requires:" "$PATTERN_DIR"/*/*.yaml 2>/dev/null | while read file; do
    pattern=$(basename "$file" .yaml)
    deps=$(grep -A5 "requires:" "$file" | grep "    -" | sed 's/    - //')
    if [ ! -z "$deps" ]; then
        echo "$pattern requires: $deps" >> "$OUTPUT_FILE"
    fi
done

# Pattern composition opportunities
echo -e "\n=== Composition Opportunities ===" >> "$OUTPUT_FILE"
echo "Patterns that enable others:" >> "$OUTPUT_FILE"
grep -l "enables:" "$PATTERN_DIR"/*/*.yaml 2>/dev/null | while read file; do
    pattern=$(basename "$file" .yaml)
    enables=$(grep -A5 "enables:" "$file" | grep "    -" | sed 's/    - //')
    if [ ! -z "$enables" ]; then
        echo "$pattern enables: $enables" >> "$OUTPUT_FILE"
    fi
done

# Recently modified patterns
echo -e "\n=== Recent Pattern Activity ===" >> "$OUTPUT_FILE"
echo "Patterns modified in last 24h:" >> "$OUTPUT_FILE"
find "$PATTERN_DIR" -name "*.yaml" -mtime -1 -exec basename {} .yaml \; 2>/dev/null >> "$OUTPUT_FILE"

# Pattern efficiency analysis
echo -e "\n=== Pattern Efficiency Analysis ===" >> "$OUTPUT_FILE"
echo "High-value patterns (confidence * success_rate > 0.8):" >> "$OUTPUT_FILE"
for pattern_file in $(find "$PATTERN_DIR" -name "*.yaml" 2>/dev/null); do
    confidence=$(grep -A1 "confidence:" "$pattern_file" | tail -1 | awk '{print $2}')
    success_rate=$(grep -A1 "success_rate:" "$pattern_file" | tail -1 | awk '{print $2}')
    
    if [ ! -z "$confidence" ] && [ ! -z "$success_rate" ]; then
        # Bash doesn't do floating point, so we'll use a workaround
        value=$(echo "$confidence * $success_rate" | bc -l 2>/dev/null || echo "0")
        if [ $(echo "$value > 0.8" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
            pattern_name=$(basename "$pattern_file" .yaml)
            echo "  $pattern_name: $value efficiency score" >> "$OUTPUT_FILE"
        fi
    fi
done
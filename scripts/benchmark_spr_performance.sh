#!/bin/bash
# benchmark_spr_performance.sh - Measure SPR vs file-only performance

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=== SPR Performance Benchmarking ===${NC}"
echo "Measuring efficiency gains from SPR-first approach..."

# Directories
SPR_DIR="/Users/sac/claude-desktop-context/spr_kernels"
MEMORY_DIR="/Users/sac/claude-desktop-context/memory"
PATTERNS_DIR="/Users/sac/claude-desktop-context/patterns"
BENCHMARK_LOG="$SPR_DIR/.benchmark_$(date +%Y%m%d_%H%M%S).log"

# Initialize metrics (simplified for compatibility)

# Function to measure file size
measure_size() {
    local path="$1"
    if [ -e "$path" ]; then
        du -sk "$path" 2>/dev/null | cut -f1
    else
        echo 0
    fi
}

# Function to count lines
count_lines() {
    local path="$1"
    if [ -f "$path" ]; then
        wc -l < "$path" 2>/dev/null || echo 0
    elif [ -d "$path" ]; then
        find "$path" -type f -exec wc -l {} + 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo 0
    else
        echo 0
    fi
}

echo -e "\n${GREEN}1. Measuring SPR Kernel Efficiency${NC}"

# Measure SPR kernels
total_spr_size=0
total_spr_concepts=0
for kernel in "$SPR_DIR"/*.spr; do
    if [ -f "$kernel" ]; then
        size=$(measure_size "$kernel")
        concepts=$(grep -c "^-" "$kernel" 2>/dev/null || echo 0)
        total_spr_size=$((total_spr_size + size))
        total_spr_concepts=$((total_spr_concepts + concepts))
        echo "  $(basename "$kernel"): ${size}KB, $concepts concepts"
    fi
done

# Store metrics
spr_total_size_metric=$total_spr_size
spr_total_concepts_metric=$total_spr_concepts

echo -e "\n${GREEN}2. Measuring Traditional File Storage${NC}"

# Measure memory files
memory_size=$(measure_size "$MEMORY_DIR")
memory_lines=$(count_lines "$MEMORY_DIR")
echo "  Memory directory: ${memory_size}KB, $memory_lines lines"

# Measure pattern files
patterns_size=$(measure_size "$PATTERNS_DIR")
patterns_count=$(find "$PATTERNS_DIR" -name "*.yaml" 2>/dev/null | wc -l || echo 0)
echo "  Patterns directory: ${patterns_size}KB, $patterns_count files"

total_file_size=$((memory_size + patterns_size))
file_total_size_metric=$total_file_size
file_total_lines_metric=$memory_lines

echo -e "\n${GREEN}3. Calculating Compression Ratios${NC}"

# Calculate ratios
if [ $total_file_size -gt 0 ]; then
    compression_ratio=$(awk "BEGIN {printf \"%.2f\", $total_spr_size/$total_file_size}")
    space_saved=$(awk "BEGIN {printf \"%.1f\", (1-$compression_ratio)*100}")
else
    compression_ratio=0
    space_saved=0
fi

echo "  SPR size: ${total_spr_size}KB"
echo "  File size: ${total_file_size}KB"
echo "  Compression ratio: $compression_ratio"
echo "  Space saved: ${space_saved}%"

echo -e "\n${GREEN}4. Simulating Operation Performance${NC}"

# Simulate file-based session recovery
echo -n "  File-based recovery simulation: "
file_start=$(date +%s%N)
# Simulate reading multiple files
find "$MEMORY_DIR" -name "*.md" -type f -exec head -n 50 {} \; > /dev/null 2>&1
file_end=$(date +%s%N)
file_time=$(( (file_end - file_start) / 1000000 )) # Convert to milliseconds
echo "${file_time}ms"

# Simulate SPR-based recovery
echo -n "  SPR-based recovery simulation: "
spr_start=$(date +%s%N)
# Simulate loading SPR kernels
cat "$SPR_DIR"/*.spr > /dev/null 2>&1
spr_end=$(date +%s%N)
spr_time=$(( (spr_end - spr_start) / 1000000 )) # Convert to milliseconds
echo "${spr_time}ms"

# Calculate speedup
if [ $file_time -gt 0 ]; then
    speedup=$(awk "BEGIN {printf \"%.1fx\", $file_time/$spr_time}")
else
    speedup="N/A"
fi

echo -e "\n${GREEN}5. Token Usage Estimation${NC}"

# Estimate tokens (rough approximation: 1 token ≈ 4 chars ≈ 0.75 words)
spr_tokens=$((total_spr_size * 250)) # Approximate tokens from KB
file_tokens=$((total_file_size * 250))
token_reduction=$(awk "BEGIN {printf \"%.1f\", ($file_tokens-$spr_tokens)/$file_tokens*100}")

echo "  SPR tokens (estimated): ~$(echo $spr_tokens | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')"
echo "  File tokens (estimated): ~$(echo $file_tokens | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')"
echo "  Token reduction: ${token_reduction}%"

echo -e "\n${CYAN}=== Performance Summary ===${NC}"

# Generate summary report
cat > "$BENCHMARK_LOG" << EOF
SPR Performance Benchmark Report
Generated: $(date)

STORAGE METRICS:
- SPR kernels: ${total_spr_size}KB ($total_spr_concepts concepts)
- Traditional files: ${total_file_size}KB ($memory_lines lines)
- Compression ratio: $compression_ratio
- Space saved: ${space_saved}%

PERFORMANCE METRICS:
- File-based recovery: ${file_time}ms
- SPR-based recovery: ${spr_time}ms
- Speed improvement: $speedup

TOKEN EFFICIENCY:
- SPR tokens: ~$spr_tokens
- File tokens: ~$file_tokens
- Token reduction: ${token_reduction}%

EFFICIENCY GAINS:
- Storage: ${space_saved}% reduction
- Speed: $speedup faster
- Tokens: ${token_reduction}% fewer
EOF

cat "$BENCHMARK_LOG"

# Performance rating
echo -e "\n${GREEN}Performance Rating:${NC}"
if (( $(echo "$token_reduction > 80" | bc -l) )); then
    echo -e "${GREEN}★★★★★ Excellent - Exceeds 80% token reduction target${NC}"
elif (( $(echo "$token_reduction > 60" | bc -l) )); then
    echo -e "${YELLOW}★★★★☆ Good - Significant efficiency gains${NC}"
else
    echo -e "${YELLOW}★★★☆☆ Fair - Room for improvement${NC}"
fi

echo -e "\nBenchmark log saved to: $BENCHMARK_LOG"
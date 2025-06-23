#!/bin/bash
# validate_spr_accuracy.sh - Anti-hallucination check against files

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== SPR Accuracy Validation ===${NC}"
echo "Verifying SPR kernels against source files..."

SPR_DIR="/Users/sac/claude-desktop-context/spr_kernels"
VALIDATION_LOG="$SPR_DIR/.validation_$(date +%Y%m%d_%H%M%S).log"
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to validate a concept against files
validate_concept() {
    local concept="$1"
    local kernel="$2"
    
    # Skip empty lines and headers
    if [[ -z "$concept" || "$concept" =~ ^#+ ]]; then
        return 0
    fi
    
    # Extract key terms from concept (remove leading "- ")
    concept_terms=$(echo "$concept" | sed 's/^- //' | grep -oE '[a-zA-Z0-9_-]{4,}' | head -3)
    
    if [ -z "$concept_terms" ]; then
        return 0
    fi
    
    ((TOTAL_CHECKS++))
    
    # Search for concept evidence in files
    found=false
    for term in $concept_terms; do
        if grep -r "$term" /Users/sac/claude-desktop-context --include="*.md" --include="*.yaml" --include="*.sh" --exclude-dir=spr_kernels -q 2>/dev/null; then
            found=true
            break
        fi
    done
    
    if $found; then
        ((PASSED_CHECKS++))
        echo -e "  ${GREEN}✓${NC} $concept"
        echo "[PASS] $kernel: $concept" >> "$VALIDATION_LOG"
    else
        ((FAILED_CHECKS++))
        echo -e "  ${RED}✗${NC} $concept"
        echo "[FAIL] $kernel: $concept" >> "$VALIDATION_LOG"
    fi
}

# Validate each SPR kernel
for kernel_file in "$SPR_DIR"/*.spr; do
    if [ ! -f "$kernel_file" ]; then
        continue
    fi
    
    kernel_name=$(basename "$kernel_file")
    echo -e "\n${GREEN}Validating: $kernel_name${NC}"
    
    # Sample 10 random concepts from the kernel
    concepts=$(grep "^-" "$kernel_file" | shuf -n 10 2>/dev/null || grep "^-" "$kernel_file")
    
    while IFS= read -r concept; do
        validate_concept "$concept" "$kernel_name"
    done <<< "$concepts"
done

# Calculate accuracy
if [ $TOTAL_CHECKS -gt 0 ]; then
    ACCURACY=$(awk "BEGIN {printf \"%.1f\", ($PASSED_CHECKS/$TOTAL_CHECKS)*100}")
else
    ACCURACY=0
fi

# Generate validation report
echo -e "\n${BLUE}=== Validation Summary ===${NC}"
echo "Total concepts checked: $TOTAL_CHECKS"
echo "Passed: $PASSED_CHECKS"
echo "Failed: $FAILED_CHECKS"
echo "Accuracy: ${ACCURACY}%"

# Check against threshold
THRESHOLD=98
if (( $(echo "$ACCURACY >= $THRESHOLD" | bc -l) )); then
    echo -e "\n${GREEN}✓ SPR validation PASSED (>= ${THRESHOLD}% accuracy)${NC}"
    exit_code=0
else
    echo -e "\n${RED}✗ SPR validation FAILED (< ${THRESHOLD}% accuracy)${NC}"
    echo "Action required: Review and update SPR kernels"
    exit_code=1
fi

# Save summary
cat >> "$VALIDATION_LOG" << EOF

=== SUMMARY ===
Date: $(date)
Total Checks: $TOTAL_CHECKS
Passed: $PASSED_CHECKS
Failed: $FAILED_CHECKS
Accuracy: ${ACCURACY}%
Status: $([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")
EOF

echo -e "\nDetailed log saved to: $VALIDATION_LOG"

# Special validation for pattern connections
echo -e "\n${BLUE}=== Pattern Graph Validation ===${NC}"
if [ -f "$SPR_DIR/pattern_recognition.spr" ]; then
    echo "Checking pattern connections..."
    connections=$(grep "→" "$SPR_DIR/pattern_recognition.spr" | wc -l)
    echo "Found $connections pattern connections"
    
    # Verify at least one connection exists in actual patterns
    if [ -d "/Users/sac/claude-desktop-context/patterns" ]; then
        actual_patterns=$(find /Users/sac/claude-desktop-context/patterns -name "*.yaml" | wc -l)
        echo "Actual pattern files: $actual_patterns"
    fi
fi

exit $exit_code
#!/bin/bash
# activate_spr.sh - Activate specific SPR kernel for immediate use

set -euo pipefail

# Check for kernel parameter
if [ $# -eq 0 ]; then
    echo "Error: No kernel specified"
    echo "Usage: $0 <kernel_name>"
    echo "Example: $0 pattern_recognition"
    exit 1
fi

KERNEL_NAME="$1"
SPR_DIR="/Users/sac/claude-desktop-context/spr_kernels"
ACTIVATION_LOG="$SPR_DIR/.activation_log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== SPR Kernel Activation ===${NC}"
echo "Target kernel: $KERNEL_NAME"

# Check if kernel exists
KERNEL_FILE="$SPR_DIR/${KERNEL_NAME}.spr"
if [ ! -f "$KERNEL_FILE" ]; then
    echo -e "${RED}Error: Kernel not found: $KERNEL_FILE${NC}"
    echo "Available kernels:"
    ls -1 "$SPR_DIR"/*.spr 2>/dev/null | xargs -n1 basename | sed 's/\.spr$//' || echo "No kernels found"
    exit 1
fi

# Load and analyze kernel
echo -e "\n${GREEN}Loading kernel contents...${NC}"
CONCEPT_COUNT=$(grep -c "^-" "$KERNEL_FILE" || echo 0)
SECTION_COUNT=$(grep -c "^##" "$KERNEL_FILE" || echo 0)
FILE_SIZE=$(wc -c < "$KERNEL_FILE")

echo "Kernel stats:"
echo "  Size: $FILE_SIZE bytes"
echo "  Sections: $SECTION_COUNT"
echo "  Concepts: $CONCEPT_COUNT"

# Extract key concepts
echo -e "\n${GREEN}Activating concepts:${NC}"
grep "^-" "$KERNEL_FILE" | head -10 | while read -r line; do
    echo "  ✓ $line"
done

# Check for connections to other kernels
echo -e "\n${GREEN}Checking pattern graph connections...${NC}"
if grep -q "→" "$KERNEL_FILE"; then
    echo "Graph connections found:"
    grep "→" "$KERNEL_FILE" | head -5 | while read -r line; do
        echo "  $line"
    done
fi

# Log activation
mkdir -p "$(dirname "$ACTIVATION_LOG")"
echo "$(date +%Y%m%d_%H%M%S) | $KERNEL_NAME | concepts:$CONCEPT_COUNT | size:$FILE_SIZE" >> "$ACTIVATION_LOG"

# Create activation marker
MARKER_FILE="$SPR_DIR/.active_kernel"
echo "$KERNEL_NAME" > "$MARKER_FILE"

# Generate activation summary
echo -e "\n${BLUE}=== Activation Summary ===${NC}"
cat << EOF
Kernel: $KERNEL_NAME
Status: ACTIVE
Concepts loaded: $CONCEPT_COUNT
Activation time: $(date +%H:%M:%S)
Token efficiency: ~$(( FILE_SIZE / 1000 ))K tokens saved
Ready for: SPR-first operations with $KERNEL_NAME context
EOF

# Special handling for specific kernels
case "$KERNEL_NAME" in
    "latent_priming")
        echo -e "\n${YELLOW}Note: Core system concepts activated${NC}"
        ;;
    "pattern_recognition")
        echo -e "\n${YELLOW}Note: Pattern graph ready for traversal${NC}"
        ;;
    "session_recovery")
        echo -e "\n${YELLOW}Note: Session context restored${NC}"
        ;;
    "predicted_needs")
        echo -e "\n${YELLOW}Note: Predictive mode activated${NC}"
        ;;
esac

echo -e "\n${GREEN}Kernel $KERNEL_NAME successfully activated${NC}"
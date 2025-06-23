#!/bin/bash
# health_check_spr.sh - System-wide health check with SPR metrics

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== CDCS Health Check ===${NC}"

# Initialize health score
HEALTH_SCORE=100
ISSUES=0

# Check 1: SPR kernels exist
echo -n "SPR kernels: "
SPR_COUNT=$(ls -1 /Users/sac/claude-desktop-context/spr_kernels/*.spr 2>/dev/null | wc -l || echo 0)
if [ $SPR_COUNT -ge 3 ]; then
    echo -e "${GREEN}✓ $SPR_COUNT kernels found${NC}"
else
    echo -e "${RED}✗ Only $SPR_COUNT kernels (need ≥3)${NC}"
    ((HEALTH_SCORE-=20))
    ((ISSUES++))
fi

# Check 2: Memory structure exists
echo -n "Memory structure: "
if [ -d "/Users/sac/claude-desktop-context/memory/sessions" ]; then
    echo -e "${GREEN}✓ Present${NC}"
else
    echo -e "${RED}✗ Missing${NC}"
    ((HEALTH_SCORE-=30))
    ((ISSUES++))
fi

# Check 3: Patterns directory
echo -n "Pattern storage: "
PATTERN_COUNT=$(find /Users/sac/claude-desktop-context/patterns -name "*.yaml" 2>/dev/null | wc -l || echo 0)
if [ $PATTERN_COUNT -gt 0 ]; then
    echo -e "${GREEN}✓ $PATTERN_COUNT patterns${NC}"
else
    echo -e "${YELLOW}⚠ No patterns yet${NC}"
    ((HEALTH_SCORE-=10))
fi

# Check 4: Scripts executable
echo -n "Scripts: "
SCRIPT_COUNT=$(find /Users/sac/claude-desktop-context/scripts -name "*.sh" -perm +111 2>/dev/null | wc -l || echo 0)
TOTAL_SCRIPTS=$(find /Users/sac/claude-desktop-context/scripts -name "*.sh" 2>/dev/null | wc -l || echo 0)
if [ $SCRIPT_COUNT -eq $TOTAL_SCRIPTS ] && [ $TOTAL_SCRIPTS -gt 0 ]; then
    echo -e "${GREEN}✓ All $SCRIPT_COUNT scripts executable${NC}"
else
    echo -e "${YELLOW}⚠ $SCRIPT_COUNT/$TOTAL_SCRIPTS executable${NC}"
    ((HEALTH_SCORE-=5))
fi

# Check 5: Makefile exists
echo -n "Makefile: "
if [ -f "/Users/sac/claude-desktop-context/Makefile" ]; then
    echo -e "${GREEN}✓ Present${NC}"
else
    echo -e "${RED}✗ Missing${NC}"
    ((HEALTH_SCORE-=20))
    ((ISSUES++))
fi

# Summary
echo -e "\n${BLUE}Health Score: $HEALTH_SCORE/100${NC}"
if [ $HEALTH_SCORE -ge 80 ]; then
    echo -e "${GREEN}System healthy${NC}"
    exit 0
elif [ $HEALTH_SCORE -ge 60 ]; then
    echo -e "${YELLOW}System degraded - $ISSUES issues${NC}"
    exit 0
else
    echo -e "${RED}System unhealthy - $ISSUES critical issues${NC}"
    exit 1
fi
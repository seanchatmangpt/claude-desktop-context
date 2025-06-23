#!/bin/bash
# Compare desktop vs mobile CDCS prompts

echo "=== CDCS System Prompt Comparison ==="
echo ""

DESKTOP_PROMPT="/Users/sac/claude-desktop-context/SYSTEM_PROMPT.md"
MOBILE_PROMPT="/Users/sac/claude-desktop-context/spr_kernels/MOBILE_SYSTEM_PROMPT.md"

# Count lines and tokens (approximate)
DESKTOP_LINES=$(wc -l < "$DESKTOP_PROMPT")
MOBILE_LINES=$(wc -l < "$MOBILE_PROMPT")

DESKTOP_CHARS=$(wc -c < "$DESKTOP_PROMPT")
MOBILE_CHARS=$(wc -c < "$MOBILE_PROMPT")

# Approximate tokens (chars/4)
DESKTOP_TOKENS=$((DESKTOP_CHARS / 4))
MOBILE_TOKENS=$((MOBILE_CHARS / 4))

echo "Desktop System Prompt (v2.2):"
echo "  Lines: $DESKTOP_LINES"
echo "  Characters: $DESKTOP_CHARS"
echo "  Approx tokens: $DESKTOP_TOKENS"
echo ""

echo "Mobile System Prompt (v3.0):"
echo "  Lines: $MOBILE_LINES"
echo "  Characters: $MOBILE_CHARS"  
echo "  Approx tokens: $MOBILE_TOKENS"
echo ""

# Calculate reduction
REDUCTION=$(( 100 - (MOBILE_TOKENS * 100 / DESKTOP_TOKENS) ))
echo "Token Reduction: ${REDUCTION}%"
echo ""

echo "=== SPR Kernels Generated ==="
ls -la /Users/sac/claude-desktop-context/spr_kernels/*.spr | while read -r line; do
    echo "$line" | awk '{print "  " $9 " (" $5 " bytes)"}'
done

echo ""
echo "=== Usage Instructions ==="
echo "1. For DESKTOP (full context): Use $DESKTOP_PROMPT"
echo "2. For MOBILE (limited context): Use $MOBILE_PROMPT" 
echo "3. SPR kernels provide semantic anchors for latent activation"
echo ""
echo "The mobile prompt activates the same capabilities in ${REDUCTION}% fewer tokens!"

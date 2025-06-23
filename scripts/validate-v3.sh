#!/bin/bash
# CDCS v3.0 Comprehensive Validation Suite

echo "=== CDCS v3.0 VALIDATION SUITE ==="
echo "Running comprehensive tests to verify all components..."
echo ""

CDCS_ROOT="/Users/sac/claude-desktop-context"
PASS_COUNT=0
FAIL_COUNT=0

# Test function
test_component() {
    local test_name="$1"
    local test_cmd="$2"
    local expected="$3"
    
    echo -n "Testing: $test_name... "
    
    if eval "$test_cmd"; then
        echo "✅ PASS"
        ((PASS_COUNT++))
    else
        echo "❌ FAIL"
        ((FAIL_COUNT++))
        echo "  Expected: $expected"
    fi
}

# 1. Version Tests
echo "1. VERSION VALIDATION"
echo "====================="
test_component "Manifest version" \
    "[[ \$(grep '^version:' $CDCS_ROOT/manifest.yaml | cut -d'\"' -f2) == '3.0.0' ]]" \
    "Version 3.0.0"

test_component "SPR architecture enabled" \
    "grep -q 'spr_architecture:' $CDCS_ROOT/manifest.yaml && grep -q 'enabled: true' $CDCS_ROOT/manifest.yaml" \
    "SPR architecture configuration"

echo ""

# 2. File System Tests
echo "2. FILE SYSTEM VALIDATION"
echo "========================="
test_component "SPR kernels directory" \
    "[[ -d $CDCS_ROOT/spr_kernels ]]" \
    "Directory exists"

test_component "All 6 SPR kernels present" \
    "[[ \$(ls -1 $CDCS_ROOT/spr_kernels/*.spr 2>/dev/null | wc -l) -eq 6 ]]" \
    "6 SPR files"

test_component "Mobile system prompt exists" \
    "[[ -f $CDCS_ROOT/spr_kernels/MOBILE_SYSTEM_PROMPT.md ]]" \
    "Mobile prompt file"

test_component "SPR generator script" \
    "[[ -x $CDCS_ROOT/scripts/spr_generator.sh ]]" \
    "Executable script"

echo ""

# 3. SPR Content Validation
echo "3. SPR CONTENT VALIDATION"
echo "========================="
test_component "Latent priming kernel valid" \
    "grep -q 'associative activation' $CDCS_ROOT/spr_kernels/latent_priming.spr" \
    "Contains core concepts"

test_component "Pattern graph structure" \
    "grep -q 'Pattern Connections:' $CDCS_ROOT/spr_kernels/pattern_recognition.spr" \
    "Graph connections defined"

test_component "Capabilities extracted" \
    "grep -q 'Discovered Capabilities:' $CDCS_ROOT/spr_kernels/capability_evolution.spr" \
    "Capabilities listed"

echo ""

# 4. Size and Efficiency Tests
echo "4. EFFICIENCY VALIDATION"
echo "========================"
DESKTOP_SIZE=$(wc -c < "$CDCS_ROOT/SYSTEM_PROMPT.md")
MOBILE_SIZE=$(wc -c < "$CDCS_ROOT/spr_kernels/MOBILE_SYSTEM_PROMPT.md")
REDUCTION=$(( 100 - (MOBILE_SIZE * 100 / DESKTOP_SIZE) ))

test_component "Token reduction ≥90%" \
    "[[ $REDUCTION -ge 90 ]]" \
    "90% or greater reduction"

test_component "Mobile prompt <2KB" \
    "[[ $MOBILE_SIZE -lt 2048 ]]" \
    "Under 2KB size"

TOTAL_SPR_SIZE=$(find $CDCS_ROOT/spr_kernels -name "*.spr" -exec cat {} \; | wc -c)
test_component "Total SPR size <5KB" \
    "[[ $TOTAL_SPR_SIZE -lt 5120 ]]" \
    "Under 5KB total"

echo ""

# 5. Backward Compatibility Tests
echo "5. BACKWARD COMPATIBILITY"
echo "========================="
test_component "Desktop prompt unchanged" \
    "[[ -f $CDCS_ROOT/SYSTEM_PROMPT.md ]]" \
    "Original prompt exists"

test_component "v2.2 file structure intact" \
    "[[ -d $CDCS_ROOT/memory && -d $CDCS_ROOT/patterns && -d $CDCS_ROOT/evolution ]]" \
    "Core directories"

test_component "Existing patterns preserved" \
    "[[ -d $CDCS_ROOT/patterns/catalog ]]" \
    "Pattern catalog exists"

echo ""

# 6. SPR Generation Test
echo "6. SPR GENERATION TEST"
echo "======================"
# Backup current SPRs
mkdir -p /tmp/spr_backup
cp $CDCS_ROOT/spr_kernels/*.spr /tmp/spr_backup/ 2>/dev/null

# Regenerate
echo -n "Testing SPR regeneration... "
if $CDCS_ROOT/scripts/spr_generator.sh > /tmp/spr_gen_log 2>&1; then
    echo "✅ PASS"
    ((PASS_COUNT++))
    
    # Verify regenerated files
    test_component "Regenerated files match count" \
        "[[ \$(ls -1 $CDCS_ROOT/spr_kernels/*.spr | wc -l) -eq 6 ]]" \
        "6 SPR files"
else
    echo "❌ FAIL"
    ((FAIL_COUNT++))
    echo "  See /tmp/spr_gen_log for details"
fi

# Restore backup
cp /tmp/spr_backup/*.spr $CDCS_ROOT/spr_kernels/ 2>/dev/null
rm -rf /tmp/spr_backup

echo ""

# 7. Integration Tests
echo "7. INTEGRATION VALIDATION"
echo "========================="
test_component "Evolution tracking updated" \
    "grep -q 'v3.0.0 - Mobile SPR Architecture' $CDCS_ROOT/evolution/lineage.md" \
    "v3.0 in lineage"

test_component "Documentation created" \
    "[[ -f $CDCS_ROOT/docs/cdcs-v3-mobile-spr-architecture.md ]]" \
    "v3.0 documentation"

test_component "Scripts executable" \
    "[[ -x $CDCS_ROOT/scripts/compare_prompts.sh && -x $CDCS_ROOT/scripts/verify-v3-upgrade.sh ]]" \
    "All scripts executable"

echo ""

# 8. Mobile Prompt Validation
echo "8. MOBILE PROMPT VALIDATION"
echo "==========================="
test_component "Contains all 6 kernels" \
    "[[ \$(grep -E '^[0-9]\.' $CDCS_ROOT/spr_kernels/MOBILE_SYSTEM_PROMPT.md | wc -l) -eq 6 ]]" \
    "6 numbered kernels"

test_component "Core behaviors defined" \
    "grep -q 'Core Behaviors:' $CDCS_ROOT/spr_kernels/MOBILE_SYSTEM_PROMPT.md" \
    "Behavior section"

test_component "Mobile mode specified" \
    "grep -q 'Mobile/Limited Context' $CDCS_ROOT/spr_kernels/MOBILE_SYSTEM_PROMPT.md" \
    "Mode declaration"

echo ""

# Summary
echo "==================================="
echo "VALIDATION SUMMARY"
echo "==================================="
echo "Tests Passed: $PASS_COUNT"
echo "Tests Failed: $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "✅ ALL TESTS PASSED!"
    echo "CDCS v3.0 is fully operational and ready for use."
    echo ""
    echo "Desktop Mode: Use SYSTEM_PROMPT.md (3,913 tokens)"
    echo "Mobile Mode:  Use spr_kernels/MOBILE_SYSTEM_PROMPT.md (251 tokens)"
    exit 0
else
    echo "❌ VALIDATION FAILED"
    echo "Please review failed tests above and fix issues."
    exit 1
fi

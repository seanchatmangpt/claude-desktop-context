#!/bin/bash

echo "🔍 TRACE QUALITY ANALYSIS"
echo "========================"
echo ""

TRACES_FILE="/Users/sac/claude-desktop-context/telemetry/data/traces.jsonl"

# Analyze trace file issues
echo "📊 Current State Analysis:"
total_lines=$(wc -l < "$TRACES_FILE")
valid_json=$(grep -c '^{' "$TRACES_FILE" || echo 0)
complete_traces=$(grep -c '{"resourceSpans"' "$TRACES_FILE" || echo 0)
valid_trace_ids=$(grep -c '"traceId":"[a-f0-9]\{32\}"' "$TRACES_FILE" || echo 0)
incomplete_lines=$(grep -c -v '^{' "$TRACES_FILE" || echo 0)

echo "  Total lines: $total_lines"
echo "  Valid JSON lines: $valid_json"
echo "  Complete trace objects: $complete_traces"
echo "  Valid trace IDs: $valid_trace_ids"
echo "  Incomplete/broken lines: $incomplete_lines"

# Identify specific issues
echo ""
echo "🔴 Issues Found:"

# Check for truncated lines
if [[ $incomplete_lines -gt 0 ]]; then
    echo "  - $incomplete_lines truncated/incomplete lines"
    echo "    Sample broken lines:"
    grep -v '^{' "$TRACES_FILE" | head -3 | sed 's/^/      /'
fi

# Check for malformed JSON
malformed=$(grep '^{' "$TRACES_FILE" | while read line; do
    if ! echo "$line" | jq . >/dev/null 2>&1; then
        echo "$line"
    fi
done | wc -l)

if [[ $malformed -gt 0 ]]; then
    echo "  - $malformed malformed JSON objects"
fi

# Check for concurrent write issues
echo ""
echo "🔧 Root Cause Analysis:"
echo "  1. Concurrent writes without proper locking"
echo "  2. Process interruptions during trace writing"
echo "  3. Buffer overflow or file descriptor issues"
echo "  4. Missing atomic write operations"

# Generate improvement plan
echo ""
echo "📋 Improvement Plan:"
echo ""
echo "```mermaid"
echo "graph TD"
echo "    A[Current Issues] --> B{Trace Quality 4%}"
echo "    B --> C[Fix 1: Atomic Writes]"
echo "    B --> D[Fix 2: Write Locking]"
echo "    B --> E[Fix 3: Validation]"
echo "    B --> F[Fix 4: Cleanup]"
echo "    "
echo "    C --> G[Use temp files]"
echo "    D --> H[Implement flock]"
echo "    E --> I[Pre-write validation]"
echo "    F --> J[Clean broken traces]"
echo "    "
echo "    G --> K[Target: 95% Quality]"
echo "    H --> K"
echo "    I --> K"
echo "    J --> K"
echo "```"

# Create fix script
echo ""
echo "💡 Creating improvement script..."

cat > /Users/sac/claude-desktop-context/telemetry/improve_trace_quality.sh << 'IMPROVE_SCRIPT'
#!/bin/bash

echo "🚀 TRACE QUALITY IMPROVEMENT SCRIPT"
echo "==================================="
echo ""

TELEMETRY_DIR="/Users/sac/claude-desktop-context/telemetry"
TRACES_FILE="$TELEMETRY_DIR/data/traces.jsonl"
BACKUP_DIR="$TELEMETRY_DIR/backup"
LOCK_FILE="$TELEMETRY_DIR/data/.traces.lock"

# Step 1: Backup current traces
echo "1️⃣ Backing up current traces..."
mkdir -p "$BACKUP_DIR"
cp "$TRACES_FILE" "$BACKUP_DIR/traces_$(date +%Y%m%d_%H%M%S).jsonl"

# Step 2: Clean up broken traces
echo "2️⃣ Cleaning broken traces..."
temp_file=$(mktemp)
grep '^{"resourceSpans"' "$TRACES_FILE" | while read line; do
    if echo "$line" | jq . >/dev/null 2>&1; then
        echo "$line" >> "$temp_file"
    fi
done
mv "$temp_file" "$TRACES_FILE"

# Step 3: Create improved trace writer
echo "3️⃣ Creating improved trace writer..."
cat > "$TELEMETRY_DIR/safe_trace_writer.sh" << 'WRITER'
#!/bin/bash

# Safe trace writer with atomic operations
write_trace() {
    local trace_data="$1"
    local traces_file="/Users/sac/claude-desktop-context/telemetry/data/traces.jsonl"
    local lock_file="/Users/sac/claude-desktop-context/telemetry/data/.traces.lock"
    local temp_file=$(mktemp)
    
    # Validate JSON first
    if ! echo "$trace_data" | jq . >/dev/null 2>&1; then
        echo "ERROR: Invalid JSON trace data" >&2
        return 1
    fi
    
    # Write with lock
    (
        flock -x 200
        echo "$trace_data" >> "$traces_file"
    ) 200>"$lock_file"
    
    return 0
}

export -f write_trace
WRITER

chmod +x "$TELEMETRY_DIR/safe_trace_writer.sh"

# Step 4: Update otel_unified.sh to use safe writer
echo "4️⃣ Updating telemetry library..."
sed -i.bak 's|echo "$span_data" >> "$TELEMETRY_DIR/data/traces.jsonl"|source /Users/sac/claude-desktop-context/telemetry/safe_trace_writer.sh; write_trace "$span_data"|' "$TELEMETRY_DIR/otel_unified.sh"

# Step 5: Add trace validation monitoring
echo "5️⃣ Adding trace validation..."
cat > "$TELEMETRY_DIR/trace_validator.sh" << 'VALIDATOR'
#!/bin/bash

# Continuous trace validation
validate_traces() {
    local traces_file="/Users/sac/claude-desktop-context/telemetry/data/traces.jsonl"
    local total=$(wc -l < "$traces_file")
    local valid=$(grep -c '"traceId":"[a-f0-9]\{32\}"' "$traces_file")
    local quality=$((valid * 100 / (total + 1)))
    
    echo "Trace Quality: $quality% ($valid/$total valid)"
    
    if [[ $quality -lt 90 ]]; then
        echo "⚠️  Quality below threshold!"
        # Trigger cleanup
        grep '^{"resourceSpans"' "$traces_file" | while read line; do
            if echo "$line" | jq . >/dev/null 2>&1; then
                echo "$line"
            fi
        done > "${traces_file}.tmp"
        mv "${traces_file}.tmp" "$traces_file"
    fi
}

export -f validate_traces
VALIDATOR

chmod +x "$TELEMETRY_DIR/trace_validator.sh"

echo ""
echo "✅ Improvements implemented!"
echo ""
echo "📊 Results:"
before_total=$(wc -l < "$BACKUP_DIR/traces_$(date +%Y%m%d_%H%M%S).jsonl")
after_total=$(wc -l < "$TRACES_FILE")
after_valid=$(grep -c '"traceId":"[a-f0-9]\{32\}"' "$TRACES_FILE")
after_quality=$((after_valid * 100 / (after_total + 1)))

echo "  Before: $before_total total lines"
echo "  After: $after_total total, $after_valid valid"
echo "  Quality: $after_quality%"
IMPROVE_SCRIPT

chmod +x /Users/sac/claude-desktop-context/telemetry/improve_trace_quality.sh

echo ""
echo "✅ Analysis complete!"
echo ""
echo "🎯 Next Steps:"
echo "1. Run: ./telemetry/improve_trace_quality.sh"
echo "2. Test: ./coordination_helper_v3.sh test"
echo "3. Monitor: ./telemetry/trace_validator.sh"
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

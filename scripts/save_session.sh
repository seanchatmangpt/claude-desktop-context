#!/bin/bash
# Save current CDCS session state

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_DIR="memory/sessions/active"

echo "Saving session at $TIMESTAMP..."

# Create session directory if needed
mkdir -p "$SESSION_DIR"

# Save current context
if [ -f "memory/context/current.md" ]; then
    cp "memory/context/current.md" "$SESSION_DIR/session_$TIMESTAMP.md"
fi

# Update session link
ln -sf "$SESSION_DIR/session_$TIMESTAMP.md" "memory/sessions/current.link"

echo "Session saved: session_$TIMESTAMP.md"
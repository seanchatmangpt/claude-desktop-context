#!/bin/bash
# SPR-first session recovery

echo "[0;34m=== SPR-Based Session Recovery ===[0m"

# First try SPR recovery
if [ -f "spr_kernels/session_recovery.spr" ]; then
    echo "Activating session recovery SPR..."
    cat spr_kernels/session_recovery.spr
    echo ""
fi

# Then check for session link
if [ -L "memory/sessions/current.link" ]; then
    session=$(readlink memory/sessions/current.link)
    echo "Active session: $session"
else
    echo "No active session found"
fi

echo ""
echo "Recovery complete"
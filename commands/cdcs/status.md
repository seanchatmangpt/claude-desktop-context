---
description: Display comprehensive CDCS system status
allowed-tools: Read, Bash
---

# CDCS System Status

## System Overview
Check if CDCS is properly initialized and show version:
- Manifest version: !`grep "version:" /Users/sac/claude-desktop-context/manifest.yaml | head -1 | cut -d'"' -f2`
- System location: /Users/sac/claude-desktop-context/

## Memory Statistics
- Total sessions: !`find /Users/sac/claude-desktop-context/memory/sessions -name "*.md" 2>/dev/null | wc -l`
- Active chunks: !`ls /Users/sac/claude-desktop-context/memory/sessions/active/*.md 2>/dev/null | wc -l`
- Compressed archives: !`ls /Users/sac/claude-desktop-context/memory/sessions/compressed/*.spr 2>/dev/null | wc -l`
- Knowledge patterns: !`ls /Users/sac/claude-desktop-context/memory/knowledge/*.md 2>/dev/null | wc -l`

## Pattern System
- Available patterns: !`find /Users/sac/claude-desktop-context/patterns/catalog -name "*.yaml" 2>/dev/null | wc -l`
- Pattern categories: !`ls -d /Users/sac/claude-desktop-context/patterns/catalog/*/ 2>/dev/null | wc -l`

## Emergent Capabilities
- Discovered: !`ls /Users/sac/claude-desktop-context/emergent-capabilities/discovered/*.md 2>/dev/null | wc -l`
- Hypotheses: !`ls /Users/sac/claude-desktop-context/emergent-capabilities/hypotheses/*.md 2>/dev/null | wc -l`
- Combinations: !`ls /Users/sac/claude-desktop-context/emergent-capabilities/combinations/*.md 2>/dev/null | wc -l`

## Active Agents
Check for any running agents:
- Active agents: !`ls -d /Users/sac/claude-desktop-context/agents/active/*/ 2>/dev/null | wc -l`

## Evolution Status
- Total mutations: !`find /Users/sac/claude-desktop-context/evolution/mutations -name "*.md" 2>/dev/null | wc -l`
- Pending changes: !`ls /Users/sac/claude-desktop-context/evolution/mutations/pending/*.md 2>/dev/null | wc -l`

## System Health
Analyze and report on system health, potential issues, and recommendations.
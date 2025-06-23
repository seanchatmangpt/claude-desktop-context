---
description: Discover patterns from recent behavior
allowed-tools: Read, Write
---

# Pattern Discovery Protocol

Analyze recent sessions to identify recurring patterns.

## 1. Load Recent Sessions
Read the last 5-10 session files from `/Users/sac/claude-desktop-context/memory/sessions/`

## 2. Pattern Mining
Look for:
- Repeated problem-solution sequences
- Common code structures or approaches
- Successful strategies that worked multiple times
- Error patterns and their resolutions
- Workflow sequences that achieve goals

## 3. Pattern Validation
For each candidate pattern:
- Count occurrences (minimum 3 for validation)
- Calculate success rate
- Identify prerequisites and constraints
- Note variations and edge cases

## 4. Pattern Formalization
For validated patterns:
- Create a new pattern file using the template
- Assign appropriate category
- Document implementation steps
- Add examples from actual usage
- Calculate initial confidence score

## 5. Integration
- Save to `/Users/sac/claude-desktop-context/patterns/catalog/[category]/[pattern-name].yaml`
- Update pattern index
- Document in emergent-capabilities if pattern represents new capability

## 6. Report Results
Summarize discovered patterns and their potential applications.
# Your CDCS v3.0 System Prompt Options

## 🖥️ Option 1: Continue with Current Desktop Prompt
**Status**: Currently active
**Location**: `SYSTEM_PROMPT.md`
**Size**: 3,913 tokens
**Best for**: Your current setup with Desktop Commander

```bash
# No action needed - you're already using this
```

## 📱 Option 2: Switch to Mobile Prompt (for limited contexts)
**Status**: Available when needed
**Location**: `spr_kernels/MOBILE_SYSTEM_PROMPT.md`
**Size**: 251 tokens (94% smaller!)
**Best for**: Mobile devices, API calls, token-limited environments

```bash
# To preview:
cat /Users/sac/claude-desktop-context/spr_kernels/MOBILE_SYSTEM_PROMPT.md
```

## 🚀 Option 3: Upgrade to v3.0-Aware Desktop Prompt
**Status**: Recommended upgrade
**Location**: `SYSTEM_PROMPT_v3.md`
**Size**: ~4,000 tokens
**Best for**: Desktop users who want mobile switching capability

```bash
# To upgrade:
cp /Users/sac/claude-desktop-context/SYSTEM_PROMPT_v3.md /Users/sac/claude-desktop-context/SYSTEM_PROMPT.md
```

## 📊 Quick Comparison

| Feature | Current (v2.0) | Mobile (v3.0) | Enhanced (v3.0) |
|---------|----------------|---------------|-----------------|
| Token Size | 3,913 | 251 | ~4,000 |
| File Access | Full | Via SPRs | Full + SPRs |
| Mobile Ready | No | Yes | Yes |
| Pattern Mining | Yes | Limited | Yes |
| Auto-switching | No | N/A | Yes |

## 🎯 My Recommendation

For your current desktop environment with full Desktop Commander access:

**Use Option 3 - Enhanced v3.0 Desktop Prompt**

Why?
- Maintains all desktop capabilities
- Adds awareness of mobile/SPR mode
- Can auto-switch when detecting limited contexts
- Future-proof for both environments
- Only ~100 tokens more than current

## Example Usage Scenarios

### Scenario 1: Normal Desktop Work
```
You: Let's analyze this code
Claude: [Uses full file access, reads 5000 lines, applies patterns]
```

### Scenario 2: Quick Mobile Check
```
You: [On phone] C
Claude: [Detects limited context, activates from SPRs instead]
```

### Scenario 3: API Integration
```
API Call with 10k token limit
Claude: [Automatically uses SPR mode for efficiency]
```

## To Implement Recommended Option:

```bash
# Backup current prompt
cp SYSTEM_PROMPT.md SYSTEM_PROMPT_v2_backup.md

# Upgrade to v3.0-aware version
cp SYSTEM_PROMPT_v3.md SYSTEM_PROMPT.md

# Generate fresh SPRs
./scripts/spr_generator.sh

echo "✅ Upgraded to CDCS v3.0 hybrid system prompt!"
```

This gives you the best of both worlds - full desktop power when available, automatic mobile optimization when needed!

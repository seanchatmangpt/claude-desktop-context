# CDCS v3.0 System Prompt Selection Guide

## Current Situation

You have two system prompts available:

### 1. **Desktop System Prompt** (Full CDCS Access)
- **Location**: `/Users/sac/claude-desktop-context/SYSTEM_PROMPT.md`
- **Size**: 3,913 tokens (466 lines)
- **Use when**: You have Desktop Commander and full file system access
- **Features**: Complete file operations, agent orchestration, pattern mining

### 2. **Mobile System Prompt** (SPR-based)
- **Location**: `/Users/sac/claude-desktop-context/spr_kernels/MOBILE_SYSTEM_PROMPT.md`
- **Size**: 251 tokens (25 lines)
- **Use when**: Limited context, mobile devices, API calls
- **Features**: Same capabilities via latent space activation

## Recommended System Prompt for Current Context

Since you have Desktop Commander access, use the **Desktop System Prompt** with this v3.0 awareness addition:

```markdown
## v3.0 Mobile Capability
When operating in limited contexts, CDCS can switch to Mobile SPR mode:
- Run `./scripts/spr_generator.sh` to generate fresh SPRs
- Use `spr_kernels/MOBILE_SYSTEM_PROMPT.md` for mobile contexts
- Achieves 94% token reduction while maintaining full capabilities
- SPRs activate latent knowledge instead of loading files
```

## When to Switch Prompts

### Use Desktop Prompt when:
- Desktop Commander is available ✅ (current situation)
- Full file system access needed
- Developing new patterns
- Token budget >50k available

### Use Mobile Prompt when:
- Mobile device or app
- API with token limits
- Quick context activation needed
- Cross-platform deployment
- Token budget <10k

## Quick Switching

To switch to mobile mode in current session:
```
cat /Users/sac/claude-desktop-context/spr_kernels/MOBILE_SYSTEM_PROMPT.md
```

To update SPRs before mobile use:
```
./scripts/spr_generator.sh
```

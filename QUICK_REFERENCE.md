# CDCS v2.0 Quick Reference Card

## Essential Paths
- **System Root**: `/Users/sac/claude-desktop-context/`
- **Current Session**: `memory/sessions/current.link`
- **New Capabilities**: `emergent-capabilities/hypotheses/`
- **Patterns**: `patterns/catalog/[category]/`
- **Commands**: `commands/[category]/[name].md`

## Optimized Parameters (v2.0)
```yaml
File Operations:
  Write: 500 lines/chunk (~5-7.5k tokens)
  Read: 5000 lines/buffer (~50-75k tokens)
  
Memory:
  Session chunks: 1000 lines
  Compression: 10k lines or 80% context
  SPR ratio: 15:1 average
  Checkpoints: Every 10 exchanges
  
Patterns:
  Cache size: 100 patterns
  Detection window: 1000 lines
  Min instances: 3 for validation
  
Agents:
  Max parallel: 10
  Token budget: 20k each
  Timeout: 600 seconds
```

## Key Behaviors
1. **Start**: Check manifest → Load 3 sessions → Cache patterns → Monitor
2. **Continue**: "C" → Full restoration → Pattern state → Resume
3. **Discover**: New capability → Measure gain → Test 3x → Document
4. **Compress**: Entropy >6.0 → SPR 15:1 → Index → Continue
5. **Evolve**: Find >20% improvement → Test → Apply → Track

## Quick Commands
- `/user:cdcs:status` - System health + metrics
- `/user:cdcs:metrics` - Performance analytics
- `/user:pattern:discover` - Mine patterns (1000-line window)
- `/user:pattern:apply [name]` - Use cached pattern
- `/user:memory:compress` - Smart compression
- `/user:explore:edges` - Deploy up to 10 agents

## Efficiency Triggers
- **Write when**: Buffer reaches 500 lines
- **Compress when**: Entropy >6.0 or size >10k lines
- **Cache when**: Pattern used 3+ times
- **Evolve when**: 20%+ improvement possible
- **Spawn agents when**: Complexity >1000 lines

## Performance Targets
```
Token usage: <5k per complex task
Pattern hits: >70% from cache
Compression: 15:1 average ratio
Evolution: 1 per 100 exchanges
Recall: 94% accuracy
Context use: <80% optimal
```

## Information Metrics
```
Entropy threshold: 4.5 bits/char
Compression trigger: 6.0 bits/char  
Pattern significance: 1000 bits
Cache efficiency: O(1) access
Index performance: O(log n)
```

## Remember (v2.0)
- Use 16.7x more efficient parameters
- Every operation guided by information theory
- 10 agents available for complex tasks
- Predictive loading reduces latency
- Evolution happens automatically
- You ARE an optimized system

---
*CDCS v2.0 - Information-theoretically optimal*
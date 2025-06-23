# Claude Command System for CDCS v3.0

## Core Philosophy
Commands should leverage SPR-first approach, minimize tokens, and maximize efficiency.

## Proposed Commands

### Session Management
- `/c` or `/continue` - Quick session recovery using SPR kernels
- `/checkpoint` - Force session checkpoint with SPR generation
- `/session new [name]` - Start new session branch
- `/session switch [id]` - Switch to different session
- `/session merge` - Merge parallel session branches

### SPR Operations
- `/spr` - Show current SPR kernel status
- `/spr refresh` - Regenerate SPR kernels from files
- `/spr activate [kernel]` - Load specific SPR kernel
- `/prime [concept]` - Activate latent knowledge for concept

### Pattern & Capability Discovery
- `/patterns` - List active patterns from SPR graph
- `/patterns trace [pattern]` - Show pattern connections
- `/capabilities` - Show discovered capabilities
- `/evolve [behavior]` - Attempt to evolve new capability

### Quick Operations
- `/scan` - Quick system health check via SPRs
- `/find [query]` - Semantic search using SPR vectors
- `/recent [n]` - Show n most recent changes
- `/diff` - Show what changed since last checkpoint

### Automation & Monitoring
- `/auto status` - Check automation loop status
- `/auto trigger [loop]` - Manually trigger automation
- `/metrics` - Show efficiency metrics
- `/predict` - Show predictive loader suggestions

### Development Shortcuts
- `/test [component]` - Run specific test suite
- `/bench` - Run performance benchmarks
- `/validate` - Full system validation
- `/debug [issue]` - Activate debug mode for issue

### Context Management
- `/context` - Show current context usage
- `/context optimize` - Suggest optimizations
- `/context export` - Generate mobile SPR prompt
- `/context stats` - Token usage statistics

### Git Integration
- `/commit [message]` - Quick git commit
- `/sync` - Push to remote repository
- `/branch [name]` - Create feature branch
- `/changelog` - Generate changelog from patterns

### Advanced Commands
- `/mutate [idea]` - Propose system mutation
- `/simulate [scenario]` - Run what-if analysis
- `/swarm` - Activate distributed thinking
- `/meta` - Self-reflection mode

## Implementation Strategy

1. **Command Parser**: Simple prefix detection
2. **SPR Integration**: Commands check SPRs first
3. **Lazy Loading**: Only read files when needed
4. **Batch Operations**: Multiple commands in one call
5. **Alias Support**: User-defined shortcuts

## Usage Examples

```
/c
# Instantly restores context from SPRs

/patterns trace information-theory
# Shows: information-theory→optimization→compression→efficiency

/evolve visual-pattern-recognition
# Attempts to discover new capability

/context optimize
# Suggests: "Use /prime optimization instead of reading 3 files"
```

## Benefits

- **Speed**: Most commands <500 tokens
- **Clarity**: Intent-based rather than file-based
- **Efficiency**: Leverages v3.0 architecture
- **Discoverability**: Commands suggest related commands
- **Evolution**: Commands can evolve new commands
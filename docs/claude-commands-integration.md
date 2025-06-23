# Claude Commands Integration Guide

## Quick Start

The Claude Command System provides efficient shortcuts for CDCS operations using a `/command` syntax.

## Usage Patterns

### 1. Direct Execution
```python
# In conversation, I can run:
result = subprocess.run(['/Users/sac/claude-desktop-context/scripts/claude', '/spr'], 
                       capture_output=True, text=True)
print(result.stdout)
```

### 2. Python Import
```python
from claude_commands import ClaudeCommands
commander = ClaudeCommands()
result = commander.execute("/patterns trace information-theory")
```

### 3. Interactive Testing
```bash
$ cd /Users/sac/claude-desktop-context/scripts
$ ./claude
claude> /help
claude> /c
claude> exit
```

## Command Cheatsheet

### Most Used Commands
- `/c` - Continue session (SPR-powered)
- `/spr` - Check SPR kernel status  
- `/patterns` - Show active pattern graph
- `/scan` - Quick system health check
- `/context optimize` - Get optimization tips

### Session Flow
1. Start: `/c` (loads context from SPRs)
2. Work: Use patterns/capabilities
3. Save: `/checkpoint` (updates SPRs)
4. Switch: `/session new experiment`

### Discovery Flow  
1. `/patterns` - See what's active
2. `/patterns trace X` - Explore connections
3. `/evolve Y` - Try new capability
4. `/capabilities` - Check what evolved

## Integration with CDCS v3.0

Commands follow the SPR-first philosophy:
1. Check SPR kernels first (instant)
2. Use pattern graph for navigation
3. Only read files when needed
4. Batch operations for efficiency

## Example Workflow

```
# Starting a session
/c
> 📡 SPR Context Activated
> Active patterns: information-theory→optimization→compression

# Checking system
/scan  
> ✓ SPR Kernels: 6/6
> ✓ Sessions: 12
> ✓ Automation: Active

# Finding something
/find token optimization
> Found in patterns: optimization→compression→token-reduction

# Optimizing
/context optimize
> Suggestion: Use /prime instead of reading files
```

## Benefits Over File Operations

| Operation | Old Way | Command Way | Savings |
|-----------|---------|-------------|---------|
| Continue | Read 5 files | `/c` | 95% |
| Find pattern | grep all YAMLs | `/patterns` | 97% |
| Check health | Read multiple logs | `/scan` | 90% |
| Search | Read + parse | `/find` | 85% |

## Advanced Usage

### Command Chaining
```bash
./claude "/c && /scan && /patterns"
```

### Command Aliases
Add to your prompt:
```
Aliases:
- "continue" = /c
- "status" = /scan
- "search X" = /find X
```

### Custom Commands
Extend `claude_commands.py`:
```python
def custom_command(self, *args):
    # Your implementation
    return "Result"

# Register in __init__
self.commands['custom'] = self.custom_command
```

## Remember

- Commands are shortcuts, not replacements
- SPRs provide the speed boost
- Files remain source of truth
- Commands can evolve new commands
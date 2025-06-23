# CDCS 24/7 Automation System

An intelligent automation layer for the Claude Desktop Context System that uses ollama/qwen3 to continuously enhance patterns, optimize memory, synthesize knowledge, and evolve the system.

## Overview

The automation system runs 6 specialized agents on different schedules to maintain and improve CDCS:

1. **Pattern Miner** - Discovers recurring patterns in sessions (every 4 hours)
2. **Memory Optimizer** - Compresses sessions using SPR (daily at 2 AM)
3. **Knowledge Synthesizer** - Builds knowledge graphs across sessions (weekly)
4. **Evolution Hunter** - Identifies system improvement opportunities (every 6 hours)
5. **Predictive Loader** - Preloads context based on patterns (every 30 min during work hours)
6. **System Health Monitor** - Monitors performance and health (every 2 hours)

## Quick Start

### Prerequisites

1. **Python 3.8+** installed
2. **ollama** with qwen3 model:
   ```bash
   ollama pull qwen3
   ```
3. **Python dependencies**:
   ```bash
   cd /Users/sac/claude-desktop-context/automation
   pip3 install -r requirements.txt
   ```

### Installation

1. **Set up cron jobs**:
   ```bash
   /Users/sac/claude-desktop-context/automation/setup_cron.sh
   ```

2. **Verify installation**:
   ```bash
   python3 /Users/sac/claude-desktop-context/automation/check_status.py
   ```

3. **Monitor logs**:
   ```bash
   tail -f /Users/sac/claude-desktop-context/automation/logs/orchestrator.log
   ```

## Architecture

### Orchestrator (`cdcs_orchestrator.py`)
- Central coordinator for all agents
- Manages SQLite database for metrics
- Provides ollama interface
- Calculates system-wide metrics

### Agents

Each agent is specialized for a specific task:

#### Pattern Miner (`agents/pattern_miner.py`)
- Analyzes sessions for recurring patterns
- Uses ollama to identify high-level patterns
- Stores discovered patterns in database
- Tracks pattern confidence and usage

#### Memory Optimizer (`agents/memory_optimizer.py`)
- Implements Sparse Priming Representation (SPR)
- Compresses sessions when they exceed thresholds
- Maintains 15:1 compression ratio average
- Optimizes pattern cache for quick access

#### Knowledge Synthesizer (`agents/knowledge_synthesizer.py`)
- Builds knowledge graphs from concepts
- Identifies concept clusters
- Generates insights from relationships
- Detects knowledge gaps

#### Evolution Hunter (`agents/evolution_hunter.py`)
- Identifies performance bottlenecks
- Finds repetitive operations to automate
- Discovers capability combinations
- Tests evolution hypotheses

#### Predictive Loader (`agents/predictive_loader.py`)
- Analyzes temporal usage patterns
- Predicts next topics based on flow
- Preloads relevant resources
- Optimizes cache for quick access

#### System Health Monitor (`agents/system_health_monitor.py`)
- Monitors disk and memory usage
- Detects performance anomalies
- Analyzes error patterns
- Generates health reports

## Cron Schedule

```
# Main orchestrator - every hour
0 * * * * /usr/bin/python3 /Users/sac/claude-desktop-context/automation/cdcs_orchestrator.py

# Pattern mining - every 4 hours
0 */4 * * * [pattern_miner]

# Memory optimization - daily at 2 AM
0 2 * * * [memory_optimizer]

# Knowledge synthesis - weekly Sundays at 3 AM
0 3 * * 0 [knowledge_synthesizer]

# Evolution hunting - every 6 hours
0 */6 * * * [evolution_hunter]

# Predictive loading - every 30 min (work hours)
*/30 8-18 * * 1-5 [predictive_loader]

# Health monitoring - every 2 hours
0 */2 * * * [system_health_monitor]
```

## Database Schema

The system uses SQLite (`cdcs_intelligence.db`) with these tables:

### automation_runs
- Tracks each agent execution
- Stores performance metrics
- Records patterns found, compression achieved

### discovered_patterns
- Stores all discovered patterns
- Tracks usage count and confidence
- Calculates information gain

### system_metrics
- Records system-wide metrics
- Tracks efficiency trends
- Monitors evolution velocity

## Monitoring

### Check Status
```bash
python3 /Users/sac/claude-desktop-context/automation/check_status.py
```

Shows:
- Cron job status
- Ollama availability
- Recent runs
- System metrics
- Health status
- Log activity

### View Logs
```bash
# All logs
tail -f /Users/sac/claude-desktop-context/automation/logs/*.log

# Specific agent
tail -f /Users/sac/claude-desktop-context/automation/logs/pattern_miner.log
```

### Database Queries
```bash
sqlite3 /Users/sac/claude-desktop-context/automation/cdcs_intelligence.db

# Recent patterns
SELECT * FROM discovered_patterns ORDER BY timestamp DESC LIMIT 10;

# System metrics
SELECT * FROM system_metrics ORDER BY timestamp DESC LIMIT 1;
```

## Management

### Disable Automation
```bash
/Users/sac/claude-desktop-context/automation/disable_cron.sh
```

### Re-enable Automation
```bash
/Users/sac/claude-desktop-context/automation/setup_cron.sh
```

### Manual Agent Run
```python
from automation.cdcs_orchestrator import CDCSOrchestrator
from automation.agents.pattern_miner import PatternMiner

orchestrator = CDCSOrchestrator()
agent = PatternMiner(orchestrator)
results = agent.run()
print(results)
```

## Performance Metrics

The system tracks:
- **Context Efficiency**: Tokens used per task complexity
- **Pattern Hit Rate**: How often patterns successfully apply
- **Compression Ratio**: Average data compression achieved
- **Evolution Velocity**: Rate of system improvements
- **Knowledge Retention**: Accuracy of compressed information recall

## Security Considerations

- All operations confined to CDCS directory
- No network requests (except ollama locally)
- No credential access
- Automatic log rotation to prevent disk overflow

## Troubleshooting

### Ollama not responding
```bash
# Check ollama status
ollama list

# Restart if needed
ollama serve
```

### High disk usage
- Check health monitor alerts
- Run memory optimizer manually
- Review largest files in status report

### Pattern discovery issues
- Ensure sufficient session history
- Check ollama model availability
- Review pattern_miner.log for errors

## Future Enhancements

- Multi-model support (beyond qwen3)
- Real-time pattern application
- Distributed agent execution
- Web dashboard for monitoring
- Integration with external tools

## Contributing

To add a new agent:
1. Create agent in `agents/` directory
2. Inherit from base agent pattern
3. Implement `run()` method
4. Add to orchestrator imports
5. Configure cron schedule

---

The CDCS Automation System continuously learns and improves, making your Claude Desktop Context System more intelligent over time.

# Coordination Helper Adaptations

## Overview

This adaptation adds two critical features to the S@S coordination system:

1. **Work Freshness Monitoring** - Ensures work items don't go stale
2. **Ollama Integration** - Adds local LLM support as alternative to Claude

## Key Features

### 1. Work Freshness & Heartbeat System

**Problem Solved**: Work items can get stuck "in_progress" if agents crash or disconnect without completing/releasing work.

**Solution Components**:

- **Heartbeat Tracking**: Agents update heartbeats every 60 seconds (configurable)
- **Staleness Detection**: Automatic detection of work items without recent heartbeats
- **Recovery Options**: Three recovery strategies for stale work
  - `reassign`: Mark for reassignment to another agent
  - `fail`: Mark as failed and release
  - `retry`: Reset progress and retry with same agent
- **Background Daemon**: Optional daemon process for automatic heartbeat updates

### 2. Ollama Integration

**Problem Solved**: Claude API may not always be available or may have rate limits. Ollama provides local LLM alternative.

**Features**:

- **Multiple AI Providers**: Support for Ollama, Claude, or automatic fallback
- **Local Processing**: No internet required when using Ollama
- **Consistent Interface**: Same analysis functions work with both providers
- **Model Flexibility**: Use any Ollama-supported model (llama2, mistral, etc.)

## Installation

1. **Apply the adaptations**:
   ```bash
   chmod +x apply_adaptations.sh
   ./apply_adaptations.sh
   ```

2. **Install Ollama** (optional but recommended):
   ```bash
   # macOS
   brew install ollama
   
   # Linux
   curl -fsSL https://ollama.ai/install.sh | sh
   ```

3. **Start Ollama and pull a model**:
   ```bash
   ollama serve  # In one terminal
   ollama pull llama2  # In another terminal
   ```

## Usage Examples

### Work Freshness Management

```bash
# Start heartbeat daemon (recommended for long-running agents)
./coordination_helper.sh heartbeat-start

# Check for stale work items
./coordination_helper.sh check-stale

# Recover stale work (choose strategy)
./coordination_helper.sh recover-stale reassign  # Reassign to available agents
./coordination_helper.sh recover-stale fail      # Mark as failed
./coordination_helper.sh recover-stale retry     # Retry with same agent

# Show freshness dashboard
./coordination_helper.sh freshness-dashboard

# Enhanced work claiming (includes AI recommendation + auto-heartbeat)
./coordination_helper.sh claim-enhanced "backend_api" "Implement user auth endpoint" high development_team

# Manual heartbeat update
./coordination_helper.sh heartbeat agent_123 work_456
```

### Ollama AI Analysis

```bash
# Set Ollama as default AI provider
export AI_PROVIDER=ollama
export OLLAMA_HOST=http://localhost:11434

# Analyze work priorities with Ollama
./coordination_helper.sh ollama-priorities

# Optimize team assignments
./coordination_helper.sh ollama-optimize

# Generic AI analysis (works with any provider)
cat work_claims.json | ./coordination_helper.sh ai-analyze "Identify bottlenecks" llama2

# Use automatic provider selection (tries Ollama first, falls back to Claude)
export AI_PROVIDER=auto
./coordination_helper.sh claim-enhanced "feature" "Add dashboard" medium
```

## Configuration

### Environment Variables

```bash
# AI Provider Configuration
export AI_PROVIDER=ollama        # Options: ollama, claude, auto (default: ollama)
export OLLAMA_HOST=http://localhost:11434  # Ollama API endpoint

# Work Freshness Configuration  
export HEARTBEAT_INTERVAL=60      # Heartbeat update interval in seconds (default: 60)
export STALE_THRESHOLD=300        # Seconds before work is considered stale (default: 300)

# Existing configurations still work
export AGENT_ID=agent_$(date +%s%N)
export COORDINATION_DIR=/path/to/coordination
```

## Architecture Changes

### New Data Fields

Work claims now include:
- `last_heartbeat`: ISO timestamp of last heartbeat
- `retry_count`: Number of retry attempts (for retry recovery)
- `recovery_reason`: Reason for recovery (if recovered)
- `recovered_at`: Timestamp of recovery

Agent status includes:
- `last_heartbeat`: ISO timestamp of last agent heartbeat

### New Files Created

- `stale_work_report.json`: Temporary report of detected stale items
- `ollama_priority_analysis.json`: Ollama analysis results
- `ollama_team_optimization.json`: Team optimization suggestions
- `heartbeat_daemon.pid`: PID file for heartbeat daemon

## Best Practices

1. **Always start heartbeat daemon** for production agents:
   ```bash
   ./coordination_helper.sh heartbeat-start
   ```

2. **Check work freshness** before major operations:
   ```bash
   ./coordination_helper.sh check-stale
   ```

3. **Use enhanced claiming** for automatic heartbeat setup:
   ```bash
   ./coordination_helper.sh claim-enhanced "work_type" "description"
   ```

4. **Configure appropriate thresholds** based on your work patterns:
   ```bash
   export STALE_THRESHOLD=600  # 10 minutes for longer tasks
   ```

5. **Monitor the freshness dashboard** regularly:
   ```bash
   watch -n 30 './coordination_helper.sh freshness-dashboard'
   ```

## Troubleshooting

### Ollama Issues

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# View Ollama logs
journalctl -u ollama -f  # Linux with systemd
ollama serve  # Run in foreground to see logs

# Test Ollama directly
echo '{"prompt": "Hello"}' | curl -X POST http://localhost:11434/api/generate -d @-
```

### Heartbeat Issues

```bash
# Check daemon status
ps aux | grep heartbeat_daemon

# View daemon PID
cat $COORDINATION_DIR/heartbeat_daemon.pid

# Manually stop daemon if needed
kill $(cat $COORDINATION_DIR/heartbeat_daemon.pid)
```

### Work Recovery Issues

```bash
# Dry run - just check without recovery
./coordination_helper.sh check-stale

# View stale work report
cat $COORDINATION_DIR/stale_work_report.json | jq .

# Manual recovery of specific item
jq '.[] | select(.work_item_id == "work_123")' $COORDINATION_DIR/work_claims.json
```

## Performance Considerations

1. **Heartbeat Overhead**: Each heartbeat updates JSON files. With many agents, consider:
   - Increasing heartbeat interval for low-priority work
   - Batching heartbeat updates
   - Moving to database storage for better performance

2. **Ollama Performance**: 
   - First request to Ollama may be slow (model loading)
   - Keep Ollama running for better response times
   - Use smaller models (like phi or tinyllama) for faster responses

3. **File Locking**: The system uses file locks which may become a bottleneck with many agents:
   - Consider implementing a lock timeout
   - Monitor lock contention
   - Plan migration to database for high-scale deployments

## Future Enhancements

1. **Batch Operations**: Update multiple heartbeats in one operation
2. **Websocket Support**: Real-time heartbeat updates via websockets  
3. **Prometheus Metrics**: Export heartbeat/staleness metrics
4. **Database Backend**: PostgreSQL/SQLite for better performance
5. **Multi-Model Support**: Use different models for different analysis types
6. **Caching Layer**: Cache AI analysis results to reduce API calls

## Migration Guide

If you have existing work items without heartbeat data:

```bash
# Add heartbeat fields to existing work
jq 'map(. + {"last_heartbeat": now | strftime("%Y-%m-%dT%H:%M:%SZ")})' \
    $COORDINATION_DIR/work_claims.json > work_claims_updated.json
    
# Backup and replace
cp $COORDINATION_DIR/work_claims.json $COORDINATION_DIR/work_claims.backup.json
mv work_claims_updated.json $COORDINATION_DIR/work_claims.json
```

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs in `$COORDINATION_DIR/`
3. Ensure Ollama is properly installed and running
4. Verify file permissions on coordination directory
#!/bin/bash

##############################################################################
# Setup Script for Unified CDCS-XAVOS System
##############################################################################
#
# This script sets up the unified Claude Desktop Context System (CDCS) and
# AI Self-Sustaining System (XAVOS) integration.
#
##############################################################################

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
CDCS_DIR="${CDCS_DIR:-/Users/sac/claude-desktop-context}"
XAVOS_DIR="${XAVOS_DIR:-/Users/sac/dev/ai-self-sustaining-system}"

echo -e "${GREEN}🚀 Setting up Unified CDCS-XAVOS System${NC}"
echo "================================================"
echo ""

# Step 1: Check Prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "  ✅ $1: Found"
        return 0
    else
        echo -e "  ❌ $1: Not found"
        return 1
    fi
}

# Check required commands
MISSING_DEPS=0
check_command "python3" || ((MISSING_DEPS++))
check_command "jq" || ((MISSING_DEPS++))
check_command "bc" || ((MISSING_DEPS++))
check_command "curl" || ((MISSING_DEPS++))

# Check optional but recommended
echo ""
echo -e "${YELLOW}Checking optional dependencies...${NC}"
check_command "claude" || echo "    ℹ️  Claude CLI not found - AI features limited"
check_command "ollama" || echo "    ℹ️  Ollama not found - install for local AI"

if [ $MISSING_DEPS -gt 0 ]; then
    echo ""
    echo -e "${RED}❌ Missing required dependencies. Please install them first.${NC}"
    echo "On macOS: brew install jq bc curl python3"
    echo "On Ubuntu: sudo apt-get install jq bc curl python3"
    exit 1
fi

# Step 2: Check Directory Structure
echo ""
echo -e "${YELLOW}Step 2: Checking directory structure...${NC}"

if [ ! -d "$CDCS_DIR" ]; then
    echo -e "  ❌ CDCS directory not found: $CDCS_DIR"
    echo "     Please set CDCS_DIR environment variable"
    exit 1
else
    echo -e "  ✅ CDCS directory: $CDCS_DIR"
fi

if [ ! -d "$XAVOS_DIR" ]; then
    echo -e "  ⚠️  XAVOS directory not found: $XAVOS_DIR"
    echo "     Some features will be limited"
    echo "     To enable full features, clone: https://github.com/seanchatmangpt/ai-self-sustaining-system"
else
    echo -e "  ✅ XAVOS directory: $XAVOS_DIR"
fi

# Step 3: Apply Adaptations
echo ""
echo -e "${YELLOW}Step 3: Applying adaptations...${NC}"

# Apply coordination helper adaptations
if [ -f "$CDCS_DIR/apply_adaptations.sh" ]; then
    echo "  🔧 Applying coordination adaptations..."
    cd "$CDCS_DIR"
    ./apply_adaptations.sh
    echo -e "  ✅ Adaptations applied"
else
    echo -e "  ⚠️  Adaptations script not found - skipping"
fi

# Step 4: Create Configuration
echo ""
echo -e "${YELLOW}Step 4: Creating unified configuration...${NC}"

CONFIG_FILE="$CDCS_DIR/cdcs_xavos_config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOF
# CDCS-XAVOS Unified Configuration
system:
  mode: unified  # cdcs_only, xavos_only, unified
  
cdcs:
  memory_dir: $CDCS_DIR/memory
  max_chunk_size: 500
  compression_threshold: 6.0
  pattern_significance: 1000
  
xavos:
  coordination_dir: $XAVOS_DIR/agent_coordination
  phoenix_port: 4000
  n8n_port: 5678
  grafana_port: 3000
  
ai_providers:
  primary: claude
  fallback: ollama
  ollama_host: http://localhost:11434
  
monitoring:
  opentelemetry_endpoint: http://localhost:4318
  enable_entropy_metrics: true
  enable_coordination_metrics: true
  
self_improvement:
  cycle_interval: 3600  # 1 hour
  min_confidence: 0.8
  max_parallel_improvements: 3
EOF
    echo -e "  ✅ Configuration created: $CONFIG_FILE"
else
    echo -e "  ✅ Configuration exists: $CONFIG_FILE"
fi

# Step 5: Initialize Bridge State
echo ""
echo -e "${YELLOW}Step 5: Initializing bridge state...${NC}"

if [ -f "$CDCS_DIR/cdcs_xavos_bridge.sh" ]; then
    chmod +x "$CDCS_DIR/cdcs_xavos_bridge.sh"
    "$CDCS_DIR/cdcs_xavos_bridge.sh" init
else
    echo -e "  ⚠️  Bridge script not found - skipping initialization"
fi

# Step 6: Setup Python Environment
echo ""
echo -e "${YELLOW}Step 6: Setting up Python environment...${NC}"

# Check if virtual environment exists
if [ ! -d "$CDCS_DIR/venv" ]; then
    echo "  🐍 Creating Python virtual environment..."
    python3 -m venv "$CDCS_DIR/venv"
    echo -e "  ✅ Virtual environment created"
fi

# Install Python dependencies
echo "  📦 Installing Python dependencies..."
"$CDCS_DIR/venv/bin/pip" install -q --upgrade pip
"$CDCS_DIR/venv/bin/pip" install -q aiofiles asyncio pyyaml

# Step 7: Create Quick Start Scripts
echo ""
echo -e "${YELLOW}Step 7: Creating quick start scripts...${NC}"

# Create unified start script
cat > "$CDCS_DIR/start_unified.sh" << 'EOF'
#!/bin/bash
# Start Unified CDCS-XAVOS System

echo "🚀 Starting Unified CDCS-XAVOS System..."

# Start services based on availability
if [ -d "$XAVOS_DIR" ]; then
    echo "  Starting XAVOS coordination..."
    "$XAVOS_DIR/agent_coordination/coordination_helper.sh" heartbeat-start
fi

echo "  Starting unified bridge..."
"$CDCS_DIR/cdcs_xavos_bridge.sh" start-unified &

echo "  Starting example agent..."
"$CDCS_DIR/venv/bin/python" "$CDCS_DIR/unified_agent_example.py" &

echo ""
echo "✅ Unified system started!"
echo ""
echo "View dashboard: $CDCS_DIR/cdcs_xavos_bridge.sh dashboard"
echo "Stop with: Ctrl+C"

# Wait for interrupt
wait
EOF

chmod +x "$CDCS_DIR/start_unified.sh"
echo -e "  ✅ Created start_unified.sh"

# Create status check script  
cat > "$CDCS_DIR/check_unified_status.sh" << 'EOF'
#!/bin/bash
# Check Unified System Status

echo "🔍 Unified CDCS-XAVOS System Status"
echo "==================================="

# Check services
echo ""
echo "📊 Service Status:"

# CDCS
if [ -d "$CDCS_DIR/memory" ]; then
    echo "  ✅ CDCS: Active"
    SESSION_COUNT=$(ls -1 "$CDCS_DIR/memory/sessions" 2>/dev/null | wc -l)
    echo "     Sessions: $SESSION_COUNT"
else
    echo "  ❌ CDCS: Not initialized"
fi

# XAVOS
if [ -f "$XAVOS_DIR/agent_coordination/work_claims.json" ]; then
    echo "  ✅ XAVOS: Active"
    WORK_COUNT=$(jq 'length' "$XAVOS_DIR/agent_coordination/work_claims.json" 2>/dev/null || echo 0)
    echo "     Work items: $WORK_COUNT"
else
    echo "  ⚠️  XAVOS: Not available"
fi

# Bridge
if [ -f "$CDCS_DIR/bridge_state/unified_metrics.json" ]; then
    echo "  ✅ Bridge: Initialized"
else
    echo "  ❌ Bridge: Not initialized"
fi

# AI Providers
echo ""
echo "🤖 AI Providers:"
if command -v claude >/dev/null 2>&1; then
    echo "  ✅ Claude: Available"
else
    echo "  ❌ Claude: Not found"
fi

if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "  ✅ Ollama: Running"
else
    echo "  ⚠️  Ollama: Not running"
fi

# Show dashboard
echo ""
"$CDCS_DIR/cdcs_xavos_bridge.sh" dashboard
EOF

chmod +x "$CDCS_DIR/check_unified_status.sh"
echo -e "  ✅ Created check_unified_status.sh"

# Step 8: Final Setup Summary
echo ""
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Start Ollama (optional but recommended):"
echo "   ollama serve"
echo "   ollama pull llama2"
echo ""
echo "2. Start the unified system:"
echo "   $CDCS_DIR/start_unified.sh"
echo ""
echo "3. Check system status:"
echo "   $CDCS_DIR/check_unified_status.sh"
echo ""
echo "4. View unified dashboard:"
echo "   $CDCS_DIR/cdcs_xavos_bridge.sh dashboard"
echo ""
echo "5. Run example unified agent:"
echo "   $CDCS_DIR/venv/bin/python $CDCS_DIR/unified_agent_example.py"
echo ""
echo "📚 Documentation:"
echo "   - Adaptation Plan: $CDCS_DIR/CDCS_XAVOS_ADAPTATION_PLAN.md"
echo "   - Coordination Guide: $CDCS_DIR/COORDINATION_ADAPTATIONS.md"
echo ""
echo "🎯 Key Features Now Available:"
echo "   ✅ Unified agent coordination with nanosecond precision"
echo "   ✅ Pattern-based work generation"
echo "   ✅ Self-improvement cycles"
echo "   ✅ Dual AI support (Claude + Ollama)"
echo "   ✅ Work freshness monitoring"
echo "   ✅ Combined telemetry and metrics"
echo ""
echo -e "${GREEN}Happy building with the unified system! 🚀${NC}"
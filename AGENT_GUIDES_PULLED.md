# Agent Guides Repository - Ready for Customization

**Location**: `/Users/sac/dev/agent-guides`  
**Source**: https://github.com/seanchatmangpt/agent-guides  
**Status**: Successfully cloned and ready for customization

## 📁 Repository Structure

```
agent-guides/
├── README.md                               # Main documentation
├── claude-custom-commands.md              # Guide for creating custom commands
├── claude-code-search-best-practices.md   # Search optimization guide
├── claude-conversation-search-guide.md    # Conversation history search
├── claude-commands/                       # Ready-to-use commands
│   ├── multi-mind.md                     # Multi-specialist analysis
│   ├── analyze-function.md               # Deep code analysis
│   ├── search-prompts.md                 # Conversation search
│   ├── crud-claude-commands.md           # CRUD operations
│   └── page.md                           # Pagination helper
└── scripts/
    └── extract-claude-session.py         # Session extraction tool
```

## 🚀 Key Features Available

### 1. Multi-Mind Collaborative Analysis
- Dynamic specialist assignment (4-6 experts)
- Parallel subagent execution
- Error decorrelation through diverse perspectives
- Configurable rounds for depth

### 2. Conversation Search
- Search across all Claude conversation history
- Multi-source integration
- Pattern recognition capabilities

### 3. Code Analysis Tools
- Line-by-line function analysis
- Performance insights
- Complexity evaluation

### 4. Anti-Repetition Workflows
- Progressive knowledge building
- Avoids circular discussions
- Structured debate formats

## 🛠️ Customization Opportunities

### For WeaverGen Project
You could customize these commands for:

1. **Semantic Convention Analysis**
   ```bash
   /weavergen:multi-mind-semantic "OpenTelemetry span attributes"
   ```

2. **Architecture Review**
   ```bash
   /weavergen:analyze-layer src/weavergen/layers/runtime.py
   ```

3. **Code Generation Strategies**
   ```bash
   /weavergen:multi-mind "Weaver to Pydantic AI pipeline optimization"
   ```

### For CDCS System
Integrate with your compound intelligence:

1. **Session Recovery Enhancement**
   - Adapt search-prompts.md for better context recovery
   - Use multi-mind for complex troubleshooting

2. **Automation Loop Analysis**
   - Create specialized commands for loop health monitoring
   - Multi-specialist review of system performance

### Installation Options

**Project-Specific (Recommended for WeaverGen):**
```bash
cd /Users/sac/dev/weavergen
mkdir -p .claude/commands
cp /Users/sac/dev/agent-guides/claude-commands/*.md .claude/commands/
# Customize for WeaverGen-specific workflows
```

**Global Installation:**
```bash
mkdir -p ~/.claude/commands
cp /Users/sac/dev/agent-guides/claude-commands/*.md ~/.claude/commands/
```

## 📝 Customization Ideas

### 1. WeaverGen-Specific Commands
Create `/weavergen:semantic-to-code`:
- Phase 1: Analyze semantic convention
- Phase 2: Generate Pydantic models
- Phase 3: Validate with OTEL spans
- Phase 4: Multi-specialist review

### 2. CDCS Integration
Enhance `/compound:scale`:
- Use multi-mind pattern for parallel agents
- Integrate with SPR efficiency
- Add predictive loading based on patterns

### 3. Cross-Project Intelligence
Create `/project:context-switch`:
- Leverage conversation search for history
- Use multi-mind for context validation
- Integrate with session recovery

## 🎯 Immediate Actions

1. **Review Key Commands**
   ```bash
   cd /Users/sac/dev/agent-guides
   cat claude-commands/multi-mind.md
   cat claude-commands/analyze-function.md
   ```

2. **Test with WeaverGen**
   ```bash
   # Copy to WeaverGen for testing
   cp claude-commands/multi-mind.md /Users/sac/dev/weavergen/.claude/commands/
   # Customize for semantic conventions
   ```

3. **Create Custom Commands**
   - Adapt multi-mind for architecture reviews
   - Create Weaver-specific analysis commands
   - Integrate with 4-layer architecture

## 💡 Strategic Value

This repository provides:
- **Proven patterns** for multi-agent orchestration
- **Anti-repetition mechanisms** for better AI output
- **Search optimization** for large codebases
- **Extensible framework** for custom workflows

Perfect timing for enhancing both WeaverGen and CDCS with sophisticated agent coordination patterns!

---

**Next Step**: Review the multi-mind.md command and consider how to adapt it for WeaverGen's semantic → code pipeline.
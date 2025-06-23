# 🚀 CDCS Source Tree System - Nuxt Development Focus

## Overview

A comprehensive file tree system designed specifically for Nuxt 3 development workflows, providing intelligent navigation and architecture insights for your multi-project codebase.

## Quick Setup

```bash
# Load all aliases (add to ~/.bashrc or ~/.zshrc)
source /Users/sac/claude-desktop-context/commands/nuxt_aliases.sh

# Test the system
src-tree all                # Full project overview
nuxt-comp                   # Quick component view
focus-chat                  # Deep dive into chat project
```

## Core Commands

### 1. `src-tree` - Project Architecture Overview

**Full System Overview:**
```bash
src-tree all                # Complete overview of both projects
src-tree                    # Same as 'all'
```

**Project-Specific:**
```bash
src-tree chat              # semantic-chat-ui project focus
src-tree web               # web-ui project focus  
src-tree chat 3            # semantic-chat-ui with depth 3
```

**Cross-Project Views:**
```bash
src-tree components        # All components across projects
src-tree api               # All API routes across projects
```

### 2. `nuxt-tree` - Development Focus Commands

**Architecture Views:**
```bash
nuxt-tree components       # Vue components with line counts
nuxt-tree api             # API routes with HTTP methods
nuxt-tree pages           # Page routing structure
nuxt-tree composables     # Composables with export counts
nuxt-tree tests           # Test files overview
nuxt-tree config          # Configuration files
```

**Project Deep Dive:**
```bash
nuxt-tree focus semantic-chat-ui    # Complete project analysis
nuxt-tree focus web-ui              # Dashboard project analysis
```

## Quick Aliases for Rapid Development

### Navigation Shortcuts
```bash
cd-chat                    # Jump to semantic-chat-ui
cd-web                     # Jump to web-ui  
cd-cdcs                    # Jump to CDCS root
```

### Development Workflow
```bash
dev-chat                   # Start semantic-chat-ui dev server
dev-web                    # Start web-ui dev server
build-chat                 # Build semantic-chat-ui
build-web                  # Build web-ui
```

### Architecture Quick Views
```bash
nuxt-comp                  # Components overview
nuxt-api                   # API routes overview
nuxt-pages                 # Pages structure
nuxt-composables           # Composables overview
nuxt-tests                 # Tests overview
nuxt-config                # Config files
```

### Project Focus
```bash
focus-chat                 # Deep semantic-chat-ui analysis
focus-web                  # Deep web-ui analysis
src-chat                   # Quick chat project tree
src-web                    # Quick web project tree
```

## Project Architecture Insights

### semantic-chat-ui (AI Chat Interface)
- **Focus**: AI-powered chat with semantic commands
- **Stack**: Nuxt 3, Vue 3, TypeScript, Drizzle ORM
- **Key Features**: 
  - Semantic command processing
  - AI model integration
  - Real-time chat interface
  - Database-backed conversations

**Architecture Highlights:**
```
📦 17 Vue Components (avg 89 lines)
🧩 4 Composables (chat, LLM, semantic commands, highlighting)  
🛣️ 5 API Routes (CRUD operations for chats)
🗄️ Database schema with migrations
🧪 2 Unit tests (component + composables)
```

### web-ui (Dashboard Interface)  
- **Focus**: System monitoring and management dashboard
- **Stack**: Nuxt 3, Vue 3, TypeScript, Playwright
- **Key Features**:
  - CDCS system monitoring
  - Customer management
  - Telemetry visualization
  - Comprehensive testing

**Architecture Highlights:**
```
📦 26 Vue Components (avg 94 lines)
🧩 1 Main composable (dashboard utilities)
🛣️ 7 API Routes (customers, notifications, CDCS telemetry)
🧪 15 Test files (10 unit + 5 e2e with Playwright)
📊 Extensive test coverage with performance monitoring
```

## Intelligent Features

### 🎯 SPR-Enhanced Navigation
- **Pattern Recognition**: Understands Nuxt project structures
- **Smart Filtering**: Automatically excludes build artifacts
- **Context Awareness**: Shows relevant development areas
- **Efficiency Metrics**: Line counts, export counts, file statistics

### 🔍 Development Hotspots
- **Recently Modified**: Shows files changed in last 24h
- **Component Complexity**: Line count analysis
- **API Route Mapping**: HTTP method detection
- **Test Coverage**: Unit vs E2E test distribution

### 📊 Architecture Analytics
```
Total Projects: 2 Nuxt applications
Vue Components: 43 (semantic: 17, web: 26)
API Routes: 12 (semantic: 5, web: 7) 
TypeScript Files: 172 across both projects
Test Coverage: 17 test files with E2E + unit tests
```

## Output Examples

### Component Overview (`nuxt-comp`)
```
🎨 Vue Components Architecture
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 semantic-chat-ui components:
  • SemanticChatMessage (204 lines)
  • UserMenu (177 lines)
  • CommandPalette (79 lines)

📦 web-ui components:  
  • UserMenu (184 lines)
  • InboxMail (165 lines)
  • HomeDateRangePicker (132 lines)
```

### API Routes Overview (`nuxt-api`)
```
🛣️ API Routes Architecture
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ semantic-chat-ui API:
  🔗 POST /chats.post.ts
  🔗 GET /chats.get.ts
  🔗 DELETE /chats/[id].delete.ts

⚡ web-ui API:
  🔗 GET /cdcs/telemetry.get.ts
  🔗 GET /cdcs/status.get.ts
  🔗 GET /cdcs/patterns.get.ts
```

## Development Workflow Integration

### Morning Startup Routine
```bash
cd-cdcs                    # Navigate to workspace
src-tree all               # Get project overview
nuxt-comp                  # Check component architecture
focus-chat                 # Deep dive into active project
dev-chat                   # Start development server
```

### Code Review Workflow  
```bash
nuxt-tree focus semantic-chat-ui    # Project analysis
nuxt-tests                          # Check test coverage
nuxt-api                           # Review API structure
nuxt-comp                          # Component complexity review
```

### Architecture Planning
```bash
src-tree components        # Cross-project component analysis
src-tree api              # API consistency review
nuxt-config               # Configuration comparison
```

## Key Benefits

✅ **Rapid Navigation**: Jump between projects and focus areas instantly  
✅ **Architecture Insight**: Understand project structure at a glance  
✅ **Development Efficiency**: Quick access to components, APIs, tests  
✅ **Code Quality**: Line counts and complexity indicators  
✅ **Pattern Recognition**: Consistent Nuxt 3 project organization  
✅ **Workflow Integration**: Seamless development server management  

The system transforms your massive codebase (18K+ directories, 100K+ files) into an intelligently navigable development environment focused on your Nuxt projects' specific needs.

#!/bin/bash
# CDCS Source Tree - Nuxt Development Focus
# Usage: /src-tree [project] [depth] [mode]

PROJECT=${1:-"all"}
DEPTH=${2:-4}
MODE=${3:-"dev"}
BASE="/Users/sac/claude-desktop-context"

# Nuxt-specific ignore patterns
IGNORE_PATTERNS='node_modules|.nuxt|.output|dist|build|coverage|playwright-report|test-results|__pycache__|*.pyc|.venv|.git|pnpm-lock.yaml|package-lock.json'

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "🚀 CDCS Source Tree - Nuxt Development"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Detect Nuxt projects
detect_nuxt_projects() {
    echo "📦 Detected Nuxt Projects:"
    find "$BASE" -name "nuxt.config.ts" -o -name "nuxt.config.js" | while read config; do
        project_dir=$(dirname "$config")
        project_name=$(basename "$project_dir")
        echo "  🎯 $project_name → $project_dir"
    done
    echo ""
}

# Show project structure with development focus
show_project_structure() {
    local proj_path="$1"
    local proj_name="$2"
    
    echo "📁 $proj_name Structure:"
    
    # Core development files first
    echo "  📜 Config & Setup:"
    ls -la "$proj_path" | grep -E '\.(ts|js|json|md)$' | grep -v node_modules | awk '{print "    •", $9}'
    
    if [ -d "$proj_path/app" ]; then
        echo "  🎨 App Architecture:"
        tree -L 2 -I "$IGNORE_PATTERNS" "$proj_path/app" | sed 's/^/    /'
    fi
    
    if [ -d "$proj_path/server" ]; then
        echo "  ⚡ Server & API:"
        tree -L 3 -I "$IGNORE_PATTERNS" "$proj_path/server" | sed 's/^/    /'
    fi
    
    if [ -d "$proj_path/test" ] || [ -d "$proj_path/tests" ]; then
        echo "  🧪 Tests:"
        tree -L 2 -I "$IGNORE_PATTERNS" "$proj_path/test" "$proj_path/tests" 2>/dev/null | sed 's/^/    /'
    fi
    
    echo ""
}

# Analyze project composition
analyze_composition() {
    local proj_path="$1"
    local proj_name="$2"
    
    echo "📊 $proj_name Composition:"
    
    # Count by file type
    echo "  📝 Source Files:"
    find "$proj_path" -name "*.vue" -not -path "*/node_modules/*" | wc -l | sed 's/^/    Vue Components: /'
    find "$proj_path" -name "*.ts" -not -path "*/node_modules/*" | wc -l | sed 's/^/    TypeScript: /'
    find "$proj_path" -name "*.js" -not -path "*/node_modules/*" | wc -l | sed 's/^/    JavaScript: /'
    
    echo "  🧪 Test Files:"
    find "$proj_path" -name "*.test.*" -not -path "*/node_modules/*" | wc -l | sed 's/^/    Unit Tests: /'
    find "$proj_path" -name "*.spec.*" -not -path "*/node_modules/*" | wc -l | sed 's/^/    Spec Tests: /'
    find "$proj_path" -name "*.e2e.*" -not -path "*/node_modules/*" | wc -l | sed 's/^/    E2E Tests: /'
    
    echo "  🗂️ Structure:"
    find "$proj_path/app" -type d 2>/dev/null | wc -l | sed 's/^/    App Directories: /'
    find "$proj_path/server" -type d 2>/dev/null | wc -l | sed 's/^/    Server Directories: /'
    
    echo ""
}

# Show development hot spots
show_dev_hotspots() {
    local proj_path="$1"
    local proj_name="$2"
    
    echo "🔥 $proj_name Development Hotspots:"
    
    echo "  🎯 Key Components:"
    find "$proj_path/app/components" -name "*.vue" 2>/dev/null | head -5 | while read comp; do
        comp_name=$(basename "$comp" .vue)
        echo "    • $comp_name"
    done
    
    echo "  🚀 Composables:"
    find "$proj_path/app/composables" -name "*.ts" 2>/dev/null | while read comp; do
        comp_name=$(basename "$comp" .ts)
        echo "    • $comp_name"
    done
    
    echo "  🛣️ API Routes:"
    find "$proj_path/server/api" -name "*.ts" -o -name "*.js" 2>/dev/null | while read route; do
        route_name=$(echo "$route" | sed "s|$proj_path/server/api/||")
        echo "    • $route_name"
    done
    
    echo ""
}

# Main execution
case $PROJECT in
    "all")
        detect_nuxt_projects
        
        # Show semantic-chat-ui (main project)
        if [ -d "$BASE/semantic-chat-ui" ]; then
            show_project_structure "$BASE/semantic-chat-ui" "semantic-chat-ui (AI Chat)"
            analyze_composition "$BASE/semantic-chat-ui" "semantic-chat-ui"
            show_dev_hotspots "$BASE/semantic-chat-ui" "semantic-chat-ui"
        fi
        
        # Show web-ui (dashboard project)  
        if [ -d "$BASE/web-ui" ]; then
            show_project_structure "$BASE/web-ui" "web-ui (Dashboard)"
            analyze_composition "$BASE/web-ui" "web-ui"
            show_dev_hotspots "$BASE/web-ui" "web-ui"
        fi
        ;;
    "chat"|"semantic")
        if [ -d "$BASE/semantic-chat-ui" ]; then
            echo "🎯 Focus: Semantic Chat UI"
            tree -L $DEPTH -I "$IGNORE_PATTERNS" "$BASE/semantic-chat-ui"
            echo ""
            analyze_composition "$BASE/semantic-chat-ui" "semantic-chat-ui"
            show_dev_hotspots "$BASE/semantic-chat-ui" "semantic-chat-ui"
        fi
        ;;
    "web"|"dashboard")
        if [ -d "$BASE/web-ui" ]; then
            echo "🎯 Focus: Web Dashboard UI"
            tree -L $DEPTH -I "$IGNORE_PATTERNS" "$BASE/web-ui"
            echo ""
            analyze_composition "$BASE/web-ui" "web-ui"
            show_dev_hotspots "$BASE/web-ui" "web-ui"
        fi
        ;;
    "components")
        echo "🎨 Component Architecture:"
        find "$BASE" -path "*/app/components/*.vue" | while read comp; do
            project=$(echo "$comp" | sed "s|$BASE/||" | cut -d'/' -f1)
            comp_name=$(basename "$comp" .vue)
            echo "  📦 $project → $comp_name"
        done
        ;;
    "api")
        echo "⚡ API Architecture:"
        find "$BASE" -path "*/server/api/*" -name "*.ts" -o -name "*.js" | while read api; do
            project=$(echo "$api" | sed "s|$BASE/||" | cut -d'/' -f1)
            api_path=$(echo "$api" | sed "s|.*/server/api/||")
            echo "  🛣️ $project → $api_path"
        done
        ;;
    *)
        if [ -d "$BASE/$PROJECT" ]; then
            echo "🎯 Focus: $PROJECT"
            tree -L $DEPTH -I "$IGNORE_PATTERNS" "$BASE/$PROJECT"
        else
            echo "❌ Project '$PROJECT' not found"
            echo "💡 Available: all, chat, web, components, api"
        fi
        ;;
esac

echo "💡 Usage Examples:"
echo "  src-tree                    → Overview of all projects"
echo "  src-tree chat              → Focus on semantic-chat-ui"
echo "  src-tree web 3             → Focus on web-ui depth 3"
echo "  src-tree components        → All components across projects"
echo "  src-tree api               → All API routes across projects"

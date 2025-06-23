#!/bin/bash
# Nuxt Development Quick Commands
# Focused tree views for rapid development navigation

BASE="/Users/sac/claude-desktop-context"
IGNORE='node_modules|.nuxt|.output|dist|build|coverage|playwright-report|test-results'

case "$1" in
    "components"|"comp")
        echo "🎨 Vue Components Architecture"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        echo "📦 semantic-chat-ui components:"
        find "$BASE/semantic-chat-ui/app/components" -name "*.vue" 2>/dev/null | while read comp; do
            comp_name=$(basename "$comp" .vue)
            size=$(wc -l < "$comp" 2>/dev/null || echo "0")
            echo "  • $comp_name ($size lines)"
        done
        
        echo ""
        echo "📦 web-ui components:"
        find "$BASE/web-ui/app/components" -name "*.vue" 2>/dev/null | while read comp; do
            comp_name=$(basename "$comp" .vue)
            size=$(wc -l < "$comp" 2>/dev/null || echo "0")
            echo "  • $comp_name ($size lines)"
        done
        ;;
        
    "api"|"routes")
        echo "🛣️ API Routes Architecture"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        echo "⚡ semantic-chat-ui API:"
        find "$BASE/semantic-chat-ui/server/api" -name "*.ts" 2>/dev/null | while read route; do
            route_path=$(echo "$route" | sed "s|$BASE/semantic-chat-ui/server/api/||")
            method=$(echo "$route_path" | grep -o '\.(get|post|put|delete|patch)\.ts$' | sed 's/\.\|\.ts//g' | tr '[:lower:]' '[:upper:]')
            echo "  🔗 $method /$route_path"
        done
        
        echo ""
        echo "⚡ web-ui API:"
        find "$BASE/web-ui/server/api" -name "*.ts" 2>/dev/null | while read route; do
            route_path=$(echo "$route" | sed "s|$BASE/web-ui/server/api/||")
            method=$(echo "$route_path" | grep -o '\.(get|post|put|delete|patch)\.ts$' | sed 's/\.\|\.ts//g' | tr '[:lower:]' '[:upper:]')
            echo "  🔗 $method /$route_path"
        done
        ;;
        
    "pages")
        echo "📄 Pages Architecture"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        echo "🎯 semantic-chat-ui pages:"
        find "$BASE/semantic-chat-ui/app/pages" -name "*.vue" 2>/dev/null | while read page; do
            page_name=$(echo "$page" | sed "s|$BASE/semantic-chat-ui/app/pages/||" | sed 's/\.vue$//')
            echo "  📄 /$page_name"
        done
        
        echo ""
        echo "🎯 web-ui pages:"
        find "$BASE/web-ui/app/pages" -name "*.vue" 2>/dev/null | while read page; do
            page_name=$(echo "$page" | sed "s|$BASE/web-ui/app/pages/||" | sed 's/\.vue$//')
            echo "  📄 /$page_name"
        done
        ;;
        
    "composables")
        echo "🧩 Composables Architecture"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        echo "🚀 semantic-chat-ui composables:"
        find "$BASE/semantic-chat-ui/app/composables" -name "*.ts" 2>/dev/null | while read comp; do
            comp_name=$(basename "$comp" .ts)
            exports=$(grep -c "^export" "$comp" 2>/dev/null || echo "0")
            echo "  🧩 $comp_name ($exports exports)"
        done
        
        echo ""
        echo "🚀 web-ui composables:"
        find "$BASE/web-ui/app/composables" -name "*.ts" 2>/dev/null | while read comp; do
            comp_name=$(basename "$comp" .ts)
            exports=$(grep -c "^export" "$comp" 2>/dev/null || echo "0")
            echo "  🧩 $comp_name ($exports exports)"
        done
        ;;
        
    "tests")
        echo "🧪 Test Architecture"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        echo "🔬 semantic-chat-ui tests:"
        find "$BASE/semantic-chat-ui/test" -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | while read test; do
            test_name=$(basename "$test")
            echo "  🧪 $test_name"
        done
        
        echo ""
        echo "🔬 web-ui tests:"
        find "$BASE/web-ui/tests" -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | while read test; do
            test_name=$(basename "$test")
            echo "  🧪 $test_name"
        done
        ;;
        
    "config")
        echo "⚙️ Configuration Files"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        for project in "semantic-chat-ui" "web-ui"; do
            if [ -d "$BASE/$project" ]; then
                echo "📋 $project config:"
                ls -la "$BASE/$project" | grep -E '\.(config|json|yaml|yml|ts|js)$' | awk '{print "  ⚙️", $9}'
                echo ""
            fi
        done
        ;;
        
    "focus")
        PROJECT="$2"
        echo "🎯 Development Focus: $PROJECT"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if [ -d "$BASE/$PROJECT" ]; then
            echo "📁 Project Structure:"
            tree -L 3 -I "$IGNORE" "$BASE/$PROJECT"
            
            echo ""
            echo "🔥 Active Development Areas:"
            echo "  📝 Recent files (last 24h):"
            find "$BASE/$PROJECT" -name "*.vue" -o -name "*.ts" -o -name "*.js" | xargs ls -lat | head -5 | awk '{print "    •", $9}'
        else
            echo "❌ Project '$PROJECT' not found"
        fi
        ;;
        
    *)
        echo "🚀 Nuxt Dev Quick Commands"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "💡 Usage:"
        echo "  nuxt-tree components    → Vue components overview"
        echo "  nuxt-tree api          → API routes overview"  
        echo "  nuxt-tree pages        → Pages structure"
        echo "  nuxt-tree composables  → Composables overview"
        echo "  nuxt-tree tests        → Test files overview"
        echo "  nuxt-tree config       → Configuration files"
        echo "  nuxt-tree focus <proj> → Deep focus on project"
        echo ""
        echo "📦 Quick aliases:"
        echo "  nuxt-comp, nuxt-api, nuxt-pages, nuxt-composables"
        ;;
esac

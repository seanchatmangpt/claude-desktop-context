# Nuxt Development Tree Aliases
# Add to your ~/.bashrc or ~/.zshrc for rapid development navigation

# Main source tree commands
alias src-tree="/Users/sac/claude-desktop-context/commands/src_tree.sh"
alias nuxt-tree="/Users/sac/claude-desktop-context/commands/nuxt_tree.sh"

# Project-specific shortcuts
alias src-chat="/Users/sac/claude-desktop-context/commands/src_tree.sh chat"
alias src-web="/Users/sac/claude-desktop-context/commands/src_tree.sh web"
alias src-all="/Users/sac/claude-desktop-context/commands/src_tree.sh all"

# Development focus shortcuts
alias nuxt-comp="/Users/sac/claude-desktop-context/commands/nuxt_tree.sh components"
alias nuxt-api="/Users/sac/claude-desktop-context/commands/nuxt_tree.sh api"
alias nuxt-pages="/Users/sac/claude-desktop-context/commands/nuxt_tree.sh pages"
alias nuxt-composables="/Users/sac/claude-desktop-context/commands/nuxt_tree.sh composables"
alias nuxt-tests="/Users/sac/claude-desktop-context/commands/nuxt_tree.sh tests"
alias nuxt-config="/Users/sac/claude-desktop-context/commands/nuxt_tree.sh config"

# Quick project focus
alias focus-chat="/Users/sac/claude-desktop-context/commands/nuxt_tree.sh focus semantic-chat-ui"
alias focus-web="/Users/sac/claude-desktop-context/commands/nuxt_tree.sh focus web-ui"

# Navigation shortcuts
alias cd-chat="cd /Users/sac/claude-desktop-context/semantic-chat-ui"
alias cd-web="cd /Users/sac/claude-desktop-context/web-ui"
alias cd-cdcs="cd /Users/sac/claude-desktop-context"

# Development workflow shortcuts
alias dev-chat="cd /Users/sac/claude-desktop-context/semantic-chat-ui && npm run dev"
alias dev-web="cd /Users/sac/claude-desktop-context/web-ui && npm run dev"
alias build-chat="cd /Users/sac/claude-desktop-context/semantic-chat-ui && npm run build"
alias build-web="cd /Users/sac/claude-desktop-context/web-ui && npm run build"

echo "🚀 Nuxt Development aliases loaded"
echo "💡 Quick commands: src-tree, nuxt-comp, nuxt-api, focus-chat, dev-chat"
echo "🎯 Navigation: cd-chat, cd-web, cd-cdcs"

#!/bin/bash
# Test environment variables and NPM token setup

echo "🔐 Environment Variables Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check all API keys and tokens
check_env_var() {
    local var_name="$1"
    local display_name="$2"
    
    if [ -n "${!var_name}" ]; then
        # Show only first 10 and last 4 characters for security
        local value="${!var_name}"
        local masked="${value:0:10}...${value: -4}"
        echo "✅ $display_name: $masked"
    else
        echo "❌ $display_name: Not set"
    fi
}

# Test all environment variables
check_env_var "GITHUB_TOKEN" "GitHub Token"
check_env_var "ANTHROPIC_API_KEY" "Anthropic API Key"  
check_env_var "GITHUB_PERSONAL_ACCESS_TOKEN" "GitHub Personal Token"
check_env_var "NOTION_API_KEY" "Notion API Key"
check_env_var "TAVILY_API_KEY" "Tavily API Key"
check_env_var "NPM_TOKEN" "NPM Token"

echo ""
echo "🚀 NPM Configuration Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test npm configuration
if command -v npm >/dev/null 2>&1; then
    echo "✅ npm is installed"
    echo "📍 npm version: $(npm --version)"
    
    # Check if .npmrc exists
    if [ -f ~/.npmrc ]; then
        echo "✅ ~/.npmrc file exists"
        if grep -q "authToken" ~/.npmrc; then
            echo "✅ Auth token found in .npmrc"
        else
            echo "⚠️  No auth token in .npmrc (may need manual setup)"
        fi
    else
        echo "⚠️  ~/.npmrc file not found"
        echo "💡 To setup npm authentication:"
        echo "   echo \"//registry.npmjs.org/:_authToken=\${NPM_TOKEN}\" >> ~/.npmrc"
    fi
else
    echo "❌ npm not found"
fi

echo ""
echo "🔧 Quick Setup Commands"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Reload environment: source ~/.zshrc"
echo "Setup npm auth:     echo \"//registry.npmjs.org/:_authToken=\${NPM_TOKEN}\" >> ~/.npmrc"
echo "Test npm auth:      npm whoami"
echo "Test in project:    cd-chat && npm install"

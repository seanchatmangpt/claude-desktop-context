#!/bin/bash
# NPM Configuration Helper - Complete Setup Guide

echo "🔧 NPM Configuration Setup Guide"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check current NPM status
echo "📋 Current NPM Status:"
echo "NPM Version: $(npm --version)"
echo "Node Version: $(node --version)"
echo "NPM Registry: $(npm config get registry)"
echo "NPM Token Available: ${NPM_TOKEN:0:10}...${NPM_TOKEN: -4}"

echo ""
echo "🎯 Setup Options:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Option 1: .npmrc with environment variable
setup_npmrc_env() {
    echo "Setting up .npmrc with environment variable..."
    
    # Backup existing .npmrc if it exists
    if [ -f ~/.npmrc ]; then
        cp ~/.npmrc ~/.npmrc.backup.$(date +%Y%m%d_%H%M%S)
        echo "✅ Backed up existing .npmrc"
    fi
    
    # Create .npmrc with token from environment
    echo "//registry.npmjs.org/:_authToken=\${NPM_TOKEN}" >> ~/.npmrc
    echo "registry=https://registry.npmjs.org/" >> ~/.npmrc
    echo "✅ Created .npmrc with environment variable"
}

# Option 2: .npmrc with direct token
setup_npmrc_direct() {
    echo "Setting up .npmrc with direct token..."
    
    # Backup existing .npmrc if it exists
    if [ -f ~/.npmrc ]; then
        cp ~/.npmrc ~/.npmrc.backup.$(date +%Y%m%d_%H%M%S)
        echo "✅ Backed up existing .npmrc"
    fi
    
    # Create .npmrc with direct token
    echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" >> ~/.npmrc
    echo "registry=https://registry.npmjs.org/" >> ~/.npmrc
    echo "✅ Created .npmrc with direct token"
}

# Option 3: npm login
setup_npm_login() {
    echo "Setting up via npm login..."
    echo "Note: This will prompt for username, password, and email"
    echo "You can also use: npm config set //registry.npmjs.org/:_authToken $NPM_TOKEN"
}

echo "1. Setup .npmrc with environment variable (recommended)"
echo "2. Setup .npmrc with direct token"
echo "3. Use npm login command"
echo "4. Show current .npmrc content"
echo "5. Test authentication"

read -p "Choose option (1-5): " choice

case $choice in
    1)
        setup_npmrc_env
        ;;
    2)
        setup_npmrc_direct
        ;;
    3)
        setup_npm_login
        ;;
    4)
        echo "📄 Current .npmrc content:"
        if [ -f ~/.npmrc ]; then
            cat ~/.npmrc
        else
            echo "No .npmrc file found"
        fi
        ;;
    5)
        echo "🧪 Testing NPM Authentication:"
        if npm whoami; then
            echo "✅ NPM authentication successful"
        else
            echo "❌ NPM authentication failed"
            echo "💡 Try running: npm config set //registry.npmjs.org/:_authToken $NPM_TOKEN"
        fi
        ;;
    *)
        echo "Invalid option"
        ;;
esac

echo ""
echo "🚀 Post-Setup Commands:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test auth:        npm whoami"
echo "View config:      npm config list"
echo "Test in chat:     cd-chat && npm install"
echo "Test in web:      cd-web && npm install"
echo "Publish package:  npm publish --access public"

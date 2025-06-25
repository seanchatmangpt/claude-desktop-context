#!/bin/bash
# One-click NPM setup with environment variable (recommended)

echo "🚀 Setting up NPM authentication with environment variable..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if NPM_TOKEN is available
if [ -z "$NPM_TOKEN" ]; then
    echo "❌ NPM_TOKEN not found in environment"
    echo "💡 Run: source ~/.zshrc"
    exit 1
fi

echo "✅ NPM_TOKEN found: ${NPM_TOKEN:0:10}...${NPM_TOKEN: -4}"

# Backup existing .npmrc if it exists
if [ -f ~/.npmrc ]; then
    backup_file="$HOME/.npmrc.backup.$(date +%Y%m%d_%H%M%S)"
    cp ~/.npmrc "$backup_file"
    echo "✅ Backed up existing .npmrc to $backup_file"
fi

# Create .npmrc with environment variable reference
cat > ~/.npmrc << EOF
//registry.npmjs.org/:_authToken=\${NPM_TOKEN}
registry=https://registry.npmjs.org/
EOF

echo "✅ Created ~/.npmrc with environment variable reference"

# Test authentication
echo ""
echo "🧪 Testing NPM authentication..."
if npm whoami 2>/dev/null; then
    echo "✅ NPM authentication successful!"
    echo "👤 Logged in as: $(npm whoami)"
else
    echo "❌ NPM authentication failed"
    echo "💡 This might be normal if the token needs verification"
fi

echo ""
echo "📋 Configuration Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ .npmrc created with environment variable reference"
echo "✅ Registry set to: https://registry.npmjs.org/"
echo "✅ Token source: \$NPM_TOKEN environment variable"

echo ""
echo "🎯 Ready to use in your projects:"
echo "cd-chat && npm install    # semantic-chat-ui"
echo "cd-web && npm install     # web-ui"
echo "npm publish --access public    # Publishing packages"

echo ""
echo "🔧 View configuration: npm config list"
echo "🧪 Test authentication: npm whoami"

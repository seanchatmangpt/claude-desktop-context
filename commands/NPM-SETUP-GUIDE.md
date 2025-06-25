# 🔧 NPM Configuration Guide - Complete Setup

## Current Status
- ✅ NPM Token added to environment (`$NPM_TOKEN`)
- ✅ npm 10.5.2 installed
- ✅ Node v20.13.0 installed  
- ❌ No `.npmrc` file configured yet

## 🎯 Setup Options

### Option 1: .npmrc with Environment Variable (Recommended)
**Best for**: Security and flexibility

```bash
# Create .npmrc that references environment variable
echo "//registry.npmjs.org/:_authToken=\${NPM_TOKEN}" >> ~/.npmrc
echo "registry=https://registry.npmjs.org/" >> ~/.npmrc
```

**Benefits:**
- Token stays in environment variable
- Can rotate token without changing .npmrc
- Works across different environments

### Option 2: .npmrc with Direct Token
**Best for**: Simple setup

```bash
# Create .npmrc with direct token
echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" >> ~/.npmrc
echo "registry=https://registry.npmjs.org/" >> ~/.npmrc
```

**Benefits:**
- Simple and direct
- No environment variable dependency

### Option 3: npm config set Command
**Best for**: CLI configuration

```bash
# Set token via npm command
npm config set //registry.npmjs.org/:_authToken $NPM_TOKEN
npm config set registry https://registry.npmjs.org/
```

**Benefits:**
- Uses npm's built-in configuration
- Automatically creates .npmrc

### Option 4: npm login (Interactive)
**Best for**: First-time setup with username/password

```bash
npm login
# Prompts for username, password, email
```

## 🚀 Quick Setup (Choose One)

### Recommended: Environment Variable Method
```bash
# Run this to set up .npmrc with environment variable
echo "//registry.npmjs.org/:_authToken=\${NPM_TOKEN}" >> ~/.npmrc
echo "registry=https://registry.npmjs.org/" >> ~/.npmrc

# Test authentication
npm whoami
```

### Alternative: Direct Token Method  
```bash
# Run this to set up .npmrc with direct token
echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" >> ~/.npmrc
echo "registry=https://registry.npmjs.org/" >> ~/.npmrc

# Test authentication
npm whoami
```

### Alternative: npm config Method
```bash
# Use npm's built-in configuration
npm config set //registry.npmjs.org/:_authToken $NPM_TOKEN
npm config set registry https://registry.npmjs.org/

# Test authentication
npm whoami
```

## 🧪 Testing Your Setup

```bash
# Test authentication
npm whoami

# View your configuration
npm config list

# Test in your projects
cd-chat && npm install
cd-web && npm install

# Test package publishing (if needed)
npm publish --access public --dry-run
```

## 🎯 For Your Nuxt Projects

Once configured, these will work seamlessly:
```bash
# semantic-chat-ui project
cd-chat
npm install              # Uses your token
npm run dev             # Start development
npm run build           # Build for production
npm publish             # Publish package (if needed)

# web-ui project  
cd-web
npm install              # Uses your token
npm run dev             # Start development
npm run build           # Build for production
```

## 🔒 Security Best Practices

### .npmrc with Environment Variable (Most Secure)
```bash
# ~/.npmrc contains:
//registry.npmjs.org/:_authToken=${NPM_TOKEN}
registry=https://registry.npmjs.org/

# Token stored in ~/.zshrc:
export NPM_TOKEN="your_npm_token_here"
```

### Benefits:
- Token rotation only requires changing environment variable
- .npmrc can be committed to version control (token not exposed)
- Works across different environments (dev, staging, prod)

## 🛠️ Troubleshooting

### If authentication fails:
```bash
# Clear npm cache
npm cache clean --force

# Remove .npmrc and recreate
rm ~/.npmrc
echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" >> ~/.npmrc

# Test with explicit registry
npm --registry https://registry.npmjs.org/ whoami
```

### If token is invalid:
1. Check token in environment: `echo $NPM_TOKEN`
2. Verify token on npmjs.com
3. Generate new token if needed
4. Update environment variable in ~/.zshrc

## 🚀 Next Steps

1. **Choose setup method** (recommend environment variable)
2. **Run setup commands**
3. **Test with `npm whoami`**
4. **Test in your Nuxt projects**
5. **Start developing!**

Would you like me to run the setup for you using the recommended environment variable method?

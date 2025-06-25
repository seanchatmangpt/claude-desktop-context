# NPM Token Configuration
# Added to ~/.zshrc on $(date)

## NPM Token Added
```bash
export NPM_TOKEN="your_npm_token_here"
```

## Usage

This token is now available as an environment variable in all your shell sessions.

### For npm authentication:
```bash
# Option 1: Use npmrc file
echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" >> ~/.npmrc

# Option 2: Use npm login (if needed)
npm config set //registry.npmjs.org/:_authToken $NPM_TOKEN

# Option 3: Use in CI/CD or scripts
npm publish --access public --token $NPM_TOKEN
```

### For Nuxt/package.json scripts:
The token will be automatically available to npm commands in your projects:
```bash
cd-chat                # Jump to semantic-chat-ui
npm install            # Will use the token if needed
npm publish            # Will use the token for publishing
```

## Security Note

The token is now stored in your ~/.zshrc file alongside your other API keys. Make sure to:
- Keep your ~/.zshrc file secure
- Don't commit this file to version control
- Rotate the token periodically for security

## Activation

To use the token immediately in your current session:
```bash
source ~/.zshrc
```

The token will be automatically available in all new terminal sessions.

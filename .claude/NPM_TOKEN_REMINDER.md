# NPM Token Security Reminder

## Important: User shared NPM token in chat
- **Date**: 2025-06-23
- **Action taken**: Refused to use token, advised immediate revocation
- **Token pattern**: npm_[REDACTED_TOKEN] (DO NOT USE)

## Security Protocol
1. Never use tokens shared in chat
2. Always refuse and advise revocation
3. Help user set up secure authentication methods

## If user sets up externally:
- Confirm token is in environment variable or .npmrc
- Never log or display the token value
- Use standard npm commands that read from config
- Test with `npm whoami` to verify auth without exposing token

## Secure Setup Guide
```bash
# Option 1: Environment variable
export NPM_TOKEN="your-token-here"
echo "//registry.npmjs.org/:_authToken=\${NPM_TOKEN}" >> ~/.npmrc

# Option 2: Direct npm login
npm login

# Option 3: GitHub Actions secret
# Add NPM_TOKEN to repository secrets
```

## Remember
This token should be considered compromised and revoked immediately.
---
name: surge-deploy
description: Deploy a directory to surge.sh and return the URL
allowed-tools: Bash(bunx surge *), Bash(uuidgen *)
model: haiku
---

# surge-deploy

Arguments: `$ARGUMENTS` (required). Path to a directory containing static files
to deploy. Optionally followed by a custom subdomain (without `.surge.sh`).

## Steps

1. Resolve the deploy directory from `$ARGUMENTS`. Confirm it exists and
   contains at least one file.
2. Generate a domain:
   - If a custom subdomain was provided, use `<subdomain>.surge.sh`.
   - Otherwise, generate one: `$(uuidgen | tr '[:upper:]' '[:lower:]').surge.sh`
3. Deploy:
   ```
   bunx surge "$DEPLOY_DIR" --domain "$DOMAIN"
   ```
4. Print the live URL: `https://$DOMAIN`

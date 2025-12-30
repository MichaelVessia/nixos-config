---
description: Set up oxlint and oxfmt in a JavaScript/TypeScript project
---

# Initialize OXC (oxlint + oxfmt)

Set up oxlint for linting and oxfmt for formatting in this project.

## Steps

1. **Detect package manager** from lock file (bun.lock/pnpm-lock.yaml/package-lock.json)

2. **Install dev dependencies**:
   ```bash
   [bun/pnpm/npm] add -D oxlint oxfmt
   ```

3. **Create `.oxlintrc.json`** (ask about React support first):
   ```json
   {
     "$schema": "./node_modules/oxlint/configuration_schema.json",
     "plugins": ["typescript", "unicorn"],
     "env": {
       "browser": true,
       "node": true,
       "es2022": true
     },
     "ignorePatterns": ["dist/**/*", "node_modules/**/*"],
     "categories": {
       "correctness": "error"
     },
     "rules": {
       "no-unused-vars": "warn",
       "@typescript-eslint/no-explicit-any": "off",
       "no-param-reassign": "error",
       "prefer-as-const": "error",
       "default-param-last": "error",
       "@typescript-eslint/no-inferrable-types": "error",
       "prefer-arrow-callback": "error",
       "one-var": ["error", "never"]
     }
   }
   ```
   If React: add `"react"` to plugins and add:
   ```json
   "react/self-closing-comp": "error",
   "react-hooks/exhaustive-deps": "error",
   "react-hooks/rules-of-hooks": "error"
   ```

4. **Create `.oxfmtrc.json`**:
   ```json
   {
     "printWidth": 120,
     "tabWidth": 2,
     "useTabs": false,
     "semi": false,
     "singleQuote": true,
     "endOfLine": "lf",
     "ignorePatterns": [
       "**/*.css",
       "**/*.json",
       "**/*.yaml",
       "**/*.yml",
       "**/*.html",
       "**/*.md"
     ]
   }
   ```

5. **Add scripts to `package.json`** (detect src directory structure first):
   ```json
   "lint": "oxlint src/",
   "lint:fix": "oxlint --fix src/",
   "format": "oxfmt --check src/",
   "format:fix": "oxfmt src/"
   ```

6. **Summary**: List created files and added scripts.

Ask for confirmation before modifying package.json.

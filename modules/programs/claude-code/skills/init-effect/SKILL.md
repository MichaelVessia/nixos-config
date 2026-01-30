---
name: init-effect
description: Set up a project with Effect using effect-solutions agent-guided setup
allowed-tools: Bash(curl:*), Bash(ls:*), Bash(file:*), Bash(git clone:*), Bash(git pull:*), Bash(effect-solutions:*), Bash(bun:*), Bash(pnpm:*), Bash(npm:*)
---

# Effect TypeScript Setup Guide

Fetch the latest agent-guided setup instructions from effect-solutions:

```bash
curl -s https://raw.githubusercontent.com/kitlangton/effect-solutions/main/packages/website/src/lib/llm-instructions.ts
```

Extract the instruction string from the `generateLLMInstructions()` function and follow those instructions exactly to set up this repository with Effect.

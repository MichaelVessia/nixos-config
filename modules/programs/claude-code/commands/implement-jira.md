---
allowed-tools: Bash(jira:*), Bash(git:*), Task, Read, Glob, Grep, TodoWrite
description: Pull Jira ticket details and create implementation plan
---

## Context

- Current directory: !`pwd`
- Git status: !`git status`
- Jira CLI available: !`jira --version 2>/dev/null || echo "Jira CLI not found"`

## Your task

Use the Jira CLI to pull ticket information and create an implementation plan in
docs/plans/{ticket-id}-plan.md:

1. Extract the Jira ticket ID from the command arguments (e.g., "PROJ-123")
2. Use `jira issue view <ticket-id>` to fetch the ticket details including:
   - Title/Summary
   - Description
   - Acceptance criteria
   - Comments
   - Subtasks
3. Analyze the current codebase to understand relevant files and patterns
4. Create a comprehensive implementation plan using TodoWrite that includes:
   - Breaking down the ticket requirements into actionable tasks
   - Identifying files that need to be modified or created
   - Considering any architectural patterns in the codebase
   - Including testing requirements
5. Incorporate any additional context provided in the command arguments

If no ticket ID is provided, ask the user to specify one. If the Jira CLI is not
configured or the ticket is not accessible, provide guidance on setup or
permissions.

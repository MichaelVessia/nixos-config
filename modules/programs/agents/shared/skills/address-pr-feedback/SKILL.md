---
name: address-pr-feedback
description: Address all open PR comments on current branch autonomously
allowed-tools: Bash(gh *), Bash(git *), Bash(npm test*), Bash(bun test*), Bash(pnpm test*), Bash(yarn test*), Read, Edit, Write, Glob, Grep, TodoWrite
---

## Context

- Current branch: !`git branch --show-current`
- PR info: !`gh pr view --json number,title,url,reviewDecision 2>/dev/null || echo "No PR found for this branch"`

## PR Comments

!`gh pr view --json comments,reviews --jq '[.reviews[]?.comments[]?, .comments[]?] | map(select(.body != null)) | .[] | "---\nAuthor: \(.author.login)\nPath: \(.path // "general")\nLine: \(.line // "N/A")\nBody: \(.body)\n"' 2>/dev/null || echo "No comments found"`

## Review Comments (inline)

!`gh api repos/{owner}/{repo}/pulls/$(gh pr view --json number -q .number)/comments --jq '.[] | "---\nAuthor: \(.user.login)\nFile: \(.path)\nLine: \(.line // .original_line)\nBody: \(.body)\n"' 2>/dev/null || echo "No inline comments found"`

## Your task

Review and address all open PR comments on this branch. For each piece of feedback:

1. Create a TodoWrite task list with all comments to track progress
2. For each comment:
   - Find the relevant code in the codebase using the file:line reference
   - Implement the suggested change or propose a better alternative with concrete code
   - Run the test suite after each change
   - If tests pass, commit with a message referencing the feedback (e.g., "fix: address review feedback on error handling")
3. Continue autonomously until all comments are addressed
4. If you hit a blocker that needs user input, stop and explain clearly

DO NOT include any Claude attribution or "Generated with Claude Code" text in commit messages.

Mark each todo item complete as you address it. If a comment requires clarification or you disagree with the suggestion, note it and move on to the next.

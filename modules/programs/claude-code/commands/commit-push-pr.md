---
allowed-tools: Bash(git checkout --branch:*), Bash(git add:*), Bash(git status:*), Bash(git push:*), Bash(git commit:*), Bash(gh pr create:*)
description: Commit, push, and open a draft PR
---

## Context

- IMPORTANT NOTE: check for PR template in .github folder and adhere to it
- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`

## Your task

Based on the above changes:

1. Create a new branch if on main. If provided as an argument, include the JIRA
   ticket in the branch name
2. Create a single commit with an appropriate message. DO NOT include any Claude
   attribution or "Generated with Claude Code" text in the commit message.
3. Push the branch to origin
4. Create a pull request using `gh pr create --draft`. Ensure the PR title
   adheres to conventional commits format
5. Update the PR description to adhere to the template in .github folder. If you
   don't know how to fill out a section, just leave it. If no template exists,
   include at minimum a description of the changes and steps to test the PR.
6. You have the capability to call multiple tools in a single response. You MUST
   do all of the above steps in a single message using multiple tool calls. Do
   not use any other tools or do anything else. Do not send any other text or
   messages besides these tool calls.

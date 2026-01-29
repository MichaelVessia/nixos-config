---
name: jira
description: Use for all Jira-related tasks. When user mentions a ticket (PROJ-123) or shares a Jira URL, use
  the jira CLI instead of web fetching.
user-invocable: false
allowed-tools: Bash
---

# Jira CLI

Use the `jira` CLI for all Jira operations. Never web fetch Jira URLs.

## Common Commands

```bash
# View issue details
jira issue view PROJ-123

# List issues in a project
jira issue list -p PROJ

# List issues assigned to me
jira issue list -a$(jira me)

# Search with JQL
jira issue list -q "project = PROJ AND status = 'In Progress'"

# Create an issue
jira issue create -p PROJ -t Task -s "Title here" -b "Description here"

# Move issue to different status
jira issue move PROJ-123 "In Progress"

# Add a comment
jira issue comment add PROJ-123 "Comment text here"

# Assign to someone
jira issue assign PROJ-123 "email@example.com"

# Link issues
jira issue link PROJ-123 PROJ-456 "blocks"
```

## Editing Issues with Long Descriptions

**IMPORTANT**: Do NOT use stdin piping (`echo "..." | jira issue edit -b -`). It is unreliable and may result in empty or corrupted descriptions.

For multi-line descriptions, use command substitution with a temp file:

```bash
# Write description to temp file first
cat > /tmp/issue-desc.md << 'EOF'
## Summary
Multi-line description here...

## Details
- Item 1
- Item 2
EOF

# Then edit using command substitution
jira issue edit PROJ-123 -b "$(cat /tmp/issue-desc.md)" --no-input
```

For short single-line edits, inline strings work fine:

```bash
jira issue edit PROJ-123 -b "Short description" --no-input
```

## When User Shares Jira URL

Extract the ticket key from URLs like `https://company.atlassian.net/browse/PROJ-123` and run:

```bash
jira issue view PROJ-123
```

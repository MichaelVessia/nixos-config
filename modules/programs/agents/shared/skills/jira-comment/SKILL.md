---
name: jira-comment
description: Comment on a Jira ticket on Michael's behalf, clearly attributed as AI-generated. Use when asked to leave a comment or reply on Jira.
allowed-tools: Bash(jira issue comment add:*), Bash(jira issue view:*)
---

## Your task

Leave a comment on a Jira ticket on Michael's behalf. The comment must be
clearly attributed as AI-generated.

### Arguments

The user will provide:
1. A Jira ticket key (e.g., PROJ-123)
2. What they want the comment to say

### Comment format

Wrap the user's message with this template:

```
This comment was left by Michael's AI agent on his behalf.

{user's message}
```

### Steps

1. Construct the comment body using the template above.
2. Post using `jira issue comment add <TICKET-KEY> "..."`. Use `--no-input` to
   skip prompts.
3. Confirm the comment was posted.

You MUST do this in a single message. Do not ask follow-up questions.

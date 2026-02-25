---
name: gh-comment
description: Comment on a GitHub PR or issue on Michael's behalf, clearly attributed as AI-generated. Use when asked to leave a comment, reply, or respond on GitHub.
allowed-tools: Bash(gh pr comment:*), Bash(gh issue comment:*), Bash(gh pr view:*), Bash(gh issue view:*)
model: claude-haiku-4-5
---

## Your task

Leave a comment on a GitHub PR or issue on Michael's behalf. The comment must
be clearly attributed as AI-generated.

### Arguments

The user will provide:
1. A PR/issue number or URL
2. What they want the comment to say

### Comment format

Wrap the user's message with this template:

```
> This comment was left by Michael's AI agent on his behalf.

{user's message}
```

### Steps

1. Determine whether the target is a PR or issue. If a number is given without
   context, check `gh pr view` first, fall back to `gh issue view`.
2. Construct the comment body using the template above.
3. Post using `gh pr comment <target> --body "..."` or
   `gh issue comment <target> --body "..."`.
4. Output the URL of the comment or confirm it was posted.

You MUST do this in a single message. Do not ask follow-up questions.

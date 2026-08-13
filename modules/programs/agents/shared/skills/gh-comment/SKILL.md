---
name: gh-comment
description: Comment on a GitHub PR or issue on Michael's behalf, clearly attributed as AI-generated. Use when asked to leave a comment, reply, or respond on GitHub.
allowed-tools: Bash(gh pr comment:*), Bash(gh issue comment:*), Bash(gh pr view:*), Bash(gh issue view:*), Bash(gh api:*)
---

## Your task

Leave comments on a GitHub PR or issue on Michael's behalf. Every comment must
be clearly attributed as AI-generated.

### Arguments

The user will provide:
1. A PR/issue number or URL
2. What they want the comment(s) to say

### AI disclaimer

**Always** start every comment with this line, no exceptions:

```
> This comment was left by Michael's AI agent on his behalf.
```

### Inline comments preferred

When commenting on a PR, **always prefer inline reply comments** over a single
top-level comment. If the user's feedback addresses multiple files, lines, or
existing review threads, post a separate inline reply to each relevant thread or
location instead of lumping everything into one big comment.

- To list existing review comments on a PR:
  `gh api repos/{owner}/{repo}/pulls/{number}/comments`
- To reply to an existing review thread (use the `in_reply_to` field with the
  top-level review comment ID of that thread):
  `gh api repos/{owner}/{repo}/pulls/{number}/comments -f body="..." -F in_reply_to=<comment_id>`
- To list top-level issue-style comments:
  `gh api repos/{owner}/{repo}/issues/{number}/comments`
- To reply to a top-level comment thread:
  `gh api repos/{owner}/{repo}/issues/{number}/comments -f body="..."`

Fall back to a single top-level comment (`gh pr comment` / `gh issue comment`)
only when:
- The target is an issue (not a PR).
- There are no existing review threads to reply to.
- The user's message is a single general remark not tied to specific code.

### Steps

1. Determine whether the target is a PR or issue. If a number is given without
   context, check `gh pr view` first, fall back to `gh issue view`.
2. For PRs, fetch existing review comments to find threads to reply to.
3. Match the user's feedback to the appropriate threads or locations.
4. Post inline replies (each prefixed with the AI disclaimer) for each piece of
   feedback. Use a top-level comment only as a last resort.
5. Output the URL(s) of the posted comment(s) or confirm they were posted.

You MUST do this in a single message. Do not ask follow-up questions.

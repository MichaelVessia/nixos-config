---
allowed-tools: Bash, Read
description: Generate a daily kickoff note with GitHub context and recent vault activity
model: claude-haiku-4-5
---

Create today's daily note with GitHub work items and recent vault context.

## Step 1: Gather GitHub Data

Run these `gh api` queries (all repos):

```bash
# Assigned issues
gh api 'search/issues?q=assignee:@me+is:open+is:issue' --jq '.items[] | "\(.repository_url | split("/") | .[-1])#\(.number): \(.title)"'

# PRs requesting your review
gh api 'search/issues?q=review-requested:@me+is:open+is:pr' --jq '.items[] | "\(.repository_url | split("/") | .[-1])#\(.number): \(.title)"'

# Your open PRs
gh api 'search/issues?q=author:@me+is:open+is:pr' --jq '.items[] | "\(.repository_url | split("/") | .[-1])#\(.number): \(.title)"'
```

## Step 2: Gather Recent Notes

Find recent notes in `~/obsidian/Notes/`:

**Daily notes** (YYYY-MM-DD.md): last 3 days
**Other notes**: last 3 days if Monday, otherwise yesterday only

Read the found notes and extract:
- Uncompleted tasks (lines starting with `- [ ]`)
- Key context or summaries

## Step 3: Create Daily Note

Create or append to `~/obsidian/Notes/YYYY-MM-DD.md`:

```markdown
## HH:MM - Start Day

#start-day

### Assigned Issues
- [ ] repo#123: issue title
(or "None" if empty)

### PRs to Review
- [ ] repo#456: pr title
(or "None" if empty)

### My Open PRs
- repo#789: pr title
(or "None" if empty)

### Recent Context
> Uncompleted tasks or summary from recent notes
> (or "Fresh start" if nothing relevant)
```

## Guidelines

- Keep output minimal and scannable
- Use checkboxes for actionable items
- Omit empty sections or mark as "None"
- Create file with `# Journal YYYY-MM-DD` header if it doesn't exist
- Confirm creation by echoing the file path

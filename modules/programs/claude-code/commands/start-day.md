---
allowed-tools: Bash, Read
description: Generate a daily kickoff note with GitHub context and recent vault activity
model: claude-haiku-4-5
---

Create today's daily note with GitHub work items and recent vault context.

## Step 1: Gather GitHub Data

Run these `gh api` queries (all repos):

```bash
# Assigned issues (with links)
gh api 'search/issues?q=assignee:@me+is:open+is:issue' --jq '.items[] | "[\(.repository_url | split("/") | .[-1])#\(.number)](\(.html_url)): \(.title)"'

# PRs requesting your review (with links)
gh api 'search/issues?q=review-requested:@me+is:open+is:pr' --jq '.items[] | "[\(.repository_url | split("/") | .[-1])#\(.number)](\(.html_url)): \(.title)"'

# Your open PRs (with links)
gh api 'search/issues?q=author:@me+is:open+is:pr' --jq '.items[] | "[\(.repository_url | split("/") | .[-1])#\(.number)](\(.html_url)): \(.title)"'

# Get current time for header
date '+%H:%M'
```

## Step 2: Gather Recent Notes

Find recent notes in `~/obsidian/Notes/`:

**Daily notes** (YYYY-MM-DD.md): last 3 days
**Other notes**: last 3 days if Monday, otherwise yesterday only

Read the found notes and extract:
- Uncompleted tasks (lines starting with `- [ ]`)
- Key context or summaries

## Step 3: Create Daily Note

Create or append to `~/obsidian/Notes/YYYY-MM-DD.md`.

Use the time from `date '+%H:%M'` output for the header (not model-generated time).

```markdown
## HH:MM - Start Day

#start-day

### Carryover TODOs
- [ ] task from previous notes
- [ ] another incomplete task
(or "None" if no uncompleted tasks found)

### Assigned Issues
- [ ] [repo#123](https://github.com/org/repo/issues/123): issue title
(or "None" if empty)

### PRs to Review
- [ ] [repo#456](https://github.com/org/repo/pull/456): pr title
(or "None" if empty)

### My Open PRs
- [repo#789](https://github.com/org/repo/pull/789): pr title
(or "None" if empty)
```

## Guidelines

- Keep output minimal and scannable
- Use checkboxes for actionable items
- Omit empty sections or mark as "None"
- Create file with `# Journal YYYY-MM-DD` header if it doesn't exist
- Confirm creation by echoing the file path

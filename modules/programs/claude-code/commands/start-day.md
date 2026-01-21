---
allowed-tools: Bash, Read, mcp__atlassian__atlassianUserInfo, mcp__atlassian__searchJiraIssuesUsingJql, mcp__atlassian__getAccessibleAtlassianResources, mcp__google-calendar__gcal_list_events
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
```

## Step 2: Gather Jira Data

Use the Atlassian MCP to fetch Jira tickets assigned to the user:

1. Get user info with `atlassianUserInfo` to get accountId
2. Get cloud resources with `getAccessibleAtlassianResources` to get cloudId
3. Search for assigned issues with `searchJiraIssuesUsingJql`:
   - JQL: `assignee = currentUser() AND status != Done ORDER BY priority DESC`
   - Format as:
     `- [ ] [KEY-123](https://flocasts.atlassian.net/browse/KEY-123): title`

**Fallback**: If the Atlassian MCP fails, use the `jira` CLI:

```bash
jira issue list --assignee $(jira me) --status '!Done' --order-by priority --plain --no-headers --columns key,summary | while read key summary; do echo "- [ ] [$key](https://flocasts.atlassian.net/browse/$key): $summary"; done
```

## Step 3: Gather Google Calendar Meetings

Use the Google Calendar MCP to fetch today's meetings:

1. Call `gcal_list_events` with:
   - `timeMin`: today at 00:00 (RFC3339 without timezone, e.g., 2026-01-09T00:00:00)
   - `timeMax`: today at 23:59 (RFC3339 without timezone, e.g., 2026-01-09T23:59:59)
   - `maxResults`: 20
2. Format each meeting as:
   `- [ ] HH:MM - Event summary`
3. Sort by start time

## Step 4: Gather Recent Notes

Find recent notes in `~/obsidian/Notes/`:

**Daily notes** (YYYY-MM-DD.md): last 3 days **Other notes**: last 3 days if
Monday, otherwise yesterday only

Read the found notes and extract:

- Uncompleted tasks (lines starting with `- [ ]`) from TODOs sections
- Completed PR/issue items (lines with `- [x]` containing GitHub links like
  `repo#123`)

## Step 5: Create Daily Note

Create or append to `~/obsidian/Notes/YYYY-MM-DD.md`.

```markdown
## Start Day

#start-day

### Meetings

- [ ] HH:MM - Meeting from Google Calendar

### TODOs

- [ ] task from previous notes
- [ ] another incomplete task

### Jira Tickets

- [ ] [KEY-123](https://flocasts.atlassian.net/browse/KEY-123): ticket title
      (Exclude items checked off in previous notes. "None" if empty after
      filtering.)

### PRs to Review

- [ ] [repo#456](https://github.com/org/repo/pull/456): pr title (Exclude items
      checked off in previous notes. "None" if empty after filtering.)

### My Open PRs

- [repo#789](https://github.com/org/repo/pull/789): pr title (Exclude items
  checked off in previous notes. "None" if empty after filtering.)
```

## Guidelines

- Keep output minimal and scannable
- Use checkboxes for actionable items (except My Open PRs, no checkbox needed)
- Omit empty sections or mark as "None"
- Filter out PRs/issues that were checked off (`- [x]`) in previous notes (match
  by `repo#number`)
- Create file with `# Journal YYYY-MM-DD` header if it doesn't exist
- Confirm creation by echoing the file path

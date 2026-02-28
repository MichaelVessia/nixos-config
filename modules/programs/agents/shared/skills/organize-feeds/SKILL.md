---
name: organize-feeds
description: Categorize uncategorized FreshRSS feeds by sampling content and inferring the best category. Use when user says "organize feeds", "categorize feeds", or wants to clean up uncategorized subscriptions.
allowed-tools: Bash, WebFetch, AskUserQuestion
---

# Organize Uncategorized FreshRSS Feeds

Go through all feeds in the Uncategorized folder, sample their content, and
assign each to the best-fitting category.

## Environment

- `FRESHRSS_URL` - Base URL of FreshRSS instance
- `FRESHRSS_API_USER` - API username
- `FRESHRSS_API_PASSWORD` - API password

## Procedure

### 1. Authenticate

```bash
AUTH_TOKEN=$(curl -s -X POST "$FRESHRSS_URL/api/greader.php/accounts/ClientLogin" \
  -d "Email=$FRESHRSS_API_USER" \
  -d "Passwd=$FRESHRSS_API_PASSWORD" | grep -oP 'Auth=\K.*')
```

### 2. Fetch existing categories

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/tag/list?output=json" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq -r '.tags[].id' | grep 'label/' | sed 's|user/-/label/||'
```

Keep this list for matching. Note the naming style (title case, short names).

### 3. Fetch uncategorized feeds

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/list?output=json" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '[.subscriptions[] | select(.categories | length == 0 or (.categories | all(.label == "Uncategorized")))] | .[] | {id, title, url: .htmlUrl}'
```

If there are no uncategorized feeds, inform the user and stop.

### 4. Sample and categorize each feed

For each uncategorized feed:

1. **Sample the feed** using WebFetch on the feed's `htmlUrl` (or its RSS URL if
   htmlUrl is missing). Read the title, description, and a few recent post
   titles to understand its topic.

2. **Infer the best category**. Compare the feed content against existing
   categories. Prefer existing categories. Only propose a new category if
   nothing fits, keeping the name short and consistent with existing style.

3. **Collect a proposal** with: feed title, inferred category, and brief
   rationale (a few words).

### 5. Present all proposals to the user

Show a summary table of all feeds and their proposed categories. Use
AskUserQuestion to confirm the batch. Include:

- Feed name
- Proposed category (with "(new)" suffix if it would create a new category)
- Brief rationale

Let the user approve all, reject all, or provide specific overrides. If the user
provides overrides, apply those instead.

### 6. Apply categorizations

For each approved feed:

```bash
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/edit" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "ac=edit" \
  -d "s=FEED_ID" \
  -d "a=user/-/label/CATEGORY_NAME" \
  -d "r=user/-/label/Uncategorized"
```

Use `r=user/-/label/Uncategorized` to remove the old label if present.

### 7. Output results

Print a summary of what was done:

- Number of feeds categorized
- List of feeds with their new categories
- Any new categories that were created
- Any feeds that were skipped or left uncategorized

## Notes

- Token is session-based, get a fresh one each invocation.
- Feed IDs use format `feed/https://...` or `feed/NUMBER`.
- Batch the proposals so the user only needs to approve once, not per-feed.
- If a feed's website is unreachable or gives no useful content, note it in the
  summary and skip it rather than guessing.
- Fever API is read-only, always use the GReader API for mutations.

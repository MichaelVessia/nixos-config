---
name: add-feed
description: Add an RSS feed to FreshRSS with auto-categorization. Use when user provides a feed URL and wants it added to FreshRSS, or says "add feed", "subscribe to", "add rss".
allowed-tools: Bash, WebFetch, AskUserQuestion
---

# Add Feed to FreshRSS

Given a feed URL, sample its content, infer the best category, and add it.

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
CATEGORIES=$(curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/tag/list?output=json" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq -r '.tags[].id' | grep 'label/' | sed 's|user/-/label/||')
```

### 3. Sample the feed

Use WebFetch on the feed URL to read its title, description, and recent post
titles/summaries. This content is the basis for category inference.

### 4. Infer category

Compare the feed's content against the existing categories from step 2. Pick the
best match. Consider:

- Feed title and description
- Topics of recent posts
- Existing category names

If no existing category fits well, propose a short, lowercase category name
consistent with the existing naming style.

Present the chosen category to the user with AskUserQuestion, showing existing
categories as options plus the inferred pick marked "(Recommended)". Only skip
confirmation if the match is obvious (e.g., feed title contains the category
name verbatim).

### 5. Add the feed with category

```bash
RESULT=$(curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/quickadd" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "quickadd=FEED_URL")
FEED_ID=$(echo "$RESULT" | jq -r '.streamId')
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/edit" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "ac=edit" \
  -d "s=$FEED_ID" \
  -d "a=user/-/label/CATEGORY_NAME"
```

### 6. Confirm

Print the feed title, URL, and assigned category. Verify by listing subscriptions:

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/list?output=json" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq ".subscriptions[] | select(.id == \"$FEED_ID\") | {title, id, categories: [.categories[].label]}"
```

## Notes

- Token is session-based, get a fresh one each invocation
- Feed IDs use format `feed/https://example.com/rss`
- Fever API (`/api/fever.php`) is read-only, always use GReader API

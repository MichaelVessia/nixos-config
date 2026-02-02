---
name: freshrss
description: Manage RSS feeds in FreshRSS. Use when the user wants to add, list, or manage RSS feeds and subscriptions.
allowed-tools: Bash, WebFetch, AskUserQuestion
---

# FreshRSS Feed Management

Manage RSS feeds via FreshRSS Google Reader API.

## Configuration

Environment variables (from sops-nix secrets):
- `FRESHRSS_URL` - Base URL of FreshRSS instance
- `FRESHRSS_API_USER` - API username
- `FRESHRSS_API_PASSWORD` - API password

## Authentication

Get an auth token first (required for all API calls):

```bash
AUTH_TOKEN=$(curl -s -X POST "$FRESHRSS_URL/api/greader.php/accounts/ClientLogin" \
  -d "Email=$FRESHRSS_API_USER" \
  -d "Passwd=$FRESHRSS_API_PASSWORD" | grep -oP 'Auth=\K.*')
```

## Add Feed Workflow

When adding a feed, ALWAYS follow this order:

1. **List current subscriptions** (includes categories): `subscription/list?output=json`
2. **Preview the feed** using WebFetch to understand its content (title, description, recent posts)
3. **Match to existing category** based on feed content. Only propose a new category if none fit
4. **If ambiguous**, use AskUserQuestion showing existing categories as options
5. **Add the feed** then assign to category

## Common Operations

### Add a Feed (without category)

```bash
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/quickadd" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "quickadd=https://example.com/feed.xml"
```

### Add a Feed to a Category

After adding, assign to category:

```bash
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/edit" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "ac=edit" \
  -d "s=feed/FEED_ID" \
  -d "a=user/-/label/CATEGORY_NAME"
```

Or in one step (quickadd returns streamId, use it immediately):

```bash
RESULT=$(curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/quickadd" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "quickadd=https://example.com/feed.xml")
FEED_ID=$(echo "$RESULT" | jq -r '.streamId')
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/edit" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "ac=edit" \
  -d "s=$FEED_ID" \
  -d "a=user/-/label/Tech"
```

### Move Feed Between Categories

Use `a=` to add to category, `r=` to remove from category:

```bash
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/edit" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "ac=edit" \
  -d "s=feed/ID" \
  -d "a=user/-/label/NewCategory" \
  -d "r=user/-/label/OldCategory"
```

### List All Feeds

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/list?output=json" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.subscriptions[] | {title, id, url: .url}'
```

### List Categories/Folders

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/tag/list?output=json" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.tags[]'
```

### Unread Count

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/unread-count?output=json" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.unreadcounts[]'
```

### Remove a Feed

```bash
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/edit" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "ac=unsubscribe" \
  -d "s=feed/FEED_ID"
```

## Workflow

1. Authenticate to get token
2. Perform operations with token in Authorization header
3. Use `jq` to parse JSON responses

## Notes

- Token is session-based, get fresh one each time
- Feed IDs are in format `feed/https://example.com/rss`
- The Fever API (`/api/fever.php`) is read-only, use GReader API for mutations

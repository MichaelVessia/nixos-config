---
name: freshrss
description: Access and interact with my FreshRSS instance. Use for any RSS-related question, including reading articles, searching past content, finding feeds, getting recommendations, managing subscriptions, checking unread counts, or exploring what I follow.
allowed-tools: Bash, WebFetch, AskUserQuestion
---

# FreshRSS

My self-hosted RSS reader. Use this skill for anything RSS-related: browsing
articles, searching content, managing feeds, finding recommendations, answering
questions about what I read.

## Environment

Variables from sops-nix secrets:
- `FRESHRSS_URL` - Base URL of FreshRSS instance
- `FRESHRSS_API_USER` - API username
- `FRESHRSS_API_PASSWORD` - API password

## Authentication

Required before all API calls:

```bash
AUTH_TOKEN=$(curl -s -X POST "$FRESHRSS_URL/api/greader.php/accounts/ClientLogin" \
  -d "Email=$FRESHRSS_API_USER" \
  -d "Passwd=$FRESHRSS_API_PASSWORD" | grep -oP 'Auth=\K.*')
```

## Reading & Searching Articles

### Get recent items (all feeds)

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/stream/contents/reading-list?output=json&n=20" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.items[] | {title, published: .published, origin: .origin.title, summary: .summary.content[:200], href: .alternate[0].href}'
```

### Get unread items

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/stream/contents/reading-list?output=json&n=50&xt=user/-/state/com.google/read" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.items[] | {title, origin: .origin.title, href: .alternate[0].href}'
```

### Get items from a specific feed

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/stream/contents/feed%2fFEED_URL?output=json&n=20" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.items[] | {title, published: .published, summary: .summary.content[:200]}'
```

### Get items from a category

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/stream/contents/user%2f-%2flabel%2fCATEGORY_NAME?output=json&n=20" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.items[] | {title, origin: .origin.title, href: .alternate[0].href}'
```

### Get starred items

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/stream/contents/user%2f-%2fstate%2fcom.google%2fstarred?output=json&n=50" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.items[] | {title, origin: .origin.title, href: .alternate[0].href}'
```

### Search articles by keyword

FreshRSS GReader API does not have a native search endpoint. To search, fetch a
large batch of items and filter client-side with jq:

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/stream/contents/reading-list?output=json&n=200" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '[.items[] | select(.title | test("KEYWORD"; "i")) | {title, origin: .origin.title, href: .alternate[0].href}]'
```

For deeper search, also check summary content:

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/stream/contents/reading-list?output=json&n=500" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '[.items[] | select((.title // "" | test("KEYWORD"; "i")) or (.summary.content // "" | test("KEYWORD"; "i"))) | {title, origin: .origin.title, href: .alternate[0].href}]'
```

Use `&c=TIMESTAMP` (unix epoch) to paginate through older items.

### Get item stream IDs (lightweight, for pagination)

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/stream/items/ids?output=json&n=100&s=reading-list" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.itemRefs[].id'
```

## Feed Management

### List all feeds

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/list?output=json" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.subscriptions[] | {title, id, url: .url, categories: [.categories[].label]}'
```

### List categories

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/tag/list?output=json" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.tags[].id' | grep label
```

### Unread count (per feed)

```bash
curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/unread-count?output=json" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq '.unreadcounts[] | {id, count}'
```

### Add a feed

```bash
RESULT=$(curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/quickadd" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "quickadd=https://example.com/feed.xml")
FEED_ID=$(echo "$RESULT" | jq -r '.streamId')
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/edit" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "ac=edit" \
  -d "s=$FEED_ID" \
  -d "a=user/-/label/CATEGORY_NAME"
```

### Move feed between categories

```bash
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/edit" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "ac=edit" \
  -d "s=feed/ID" \
  -d "a=user/-/label/NewCategory" \
  -d "r=user/-/label/OldCategory"
```

### Remove a feed

```bash
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/edit" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "ac=unsubscribe" \
  -d "s=feed/FEED_ID"
```

### Mark as read / star

```bash
# Mark item read
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/edit-tag" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "i=ITEM_ID" \
  -d "a=user/-/state/com.google/read"

# Star item
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/edit-tag" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "i=ITEM_ID" \
  -d "a=user/-/state/com.google/starred"
```

## Recommendations

When asked for feed recommendations:

1. List all current subscriptions with categories
2. Identify themes and interests from the feed titles and categories
3. Use WebSearch to find feeds in similar topic areas that the user does not
   already subscribe to
4. Present recommendations grouped by interest area, with feed URL and a brief
   description of what the feed covers

## Notes

- Token is session-based, get a fresh one each invocation
- Feed IDs use format `feed/https://example.com/rss`
- The Fever API (`/api/fever.php`) is read-only, use GReader API for mutations
- URL-encode slashes in stream IDs when used in URL paths (`%2f`)
- `n=` controls batch size, `c=` is a continuation token (unix timestamp) for pagination
- To read full article content, use WebFetch on the article's `href`

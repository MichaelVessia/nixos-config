---
name: freshrss
description: Access and manage my FreshRSS instance. Use for RSS reading, search, recommendations, subscriptions, auto-categorization, uncategorized-feed cleanup, or subscribing to an email newsletter through Kill the Newsletter.
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

## Workflow: add and categorize a feed

1. Authenticate and fetch the existing categories.
2. Fetch the feed URL and sample its title, description, and recent posts.
3. Prefer the best-fitting existing category. Propose a short category matching
   the current naming style only when none fits.
4. Confirm the category unless the match is obvious.
5. Add the feed using `subscription/quickadd`, then assign the category using
   `subscription/edit`.
6. Verify the resulting subscription and report its title, URL, and category.

## Workflow: subscribe to an email newsletter

1. Fetch the newsletter's site to understand its subject and choose a title.
2. Create a Kill the Newsletter inbox:

   ```bash
   FEED_SLUG=$(curl -s -X POST https://kill-the-newsletter.com/feeds \
     -H "CSRF-Protection: true" \
     -d "title=NEWSLETTER_TITLE" \
     -D - -o /dev/null | grep -oP 'location:.*feeds/\K[^\s]+')
   ```

3. Add `https://kill-the-newsletter.com/feeds/${FEED_SLUG}.xml` using the feed
   workflow above.
4. Report `${FEED_SLUG}@kill-the-newsletter.com`, the private Atom feed URL,
   its FreshRSS category, and that the email address must be entered on the
   newsletter signup page. Confirmation messages will appear in FreshRSS.
5. Never share the Kill the Newsletter feed URL publicly.

## Workflow: organize uncategorized feeds

1. Fetch existing categories and subscriptions with no category or only the
   `Uncategorized` category.
2. Sample each feed's site or RSS URL. Infer an existing category where
   possible; skip feeds with insufficient evidence rather than guessing.
3. Present one batch table containing each feed, proposed category, and brief
   rationale. Let the user approve, reject, or override the proposals.
4. For approved feeds, add the selected category with `subscription/edit` and
   remove `user/-/label/Uncategorized`.
5. Report categorized, skipped, and still-uncategorized feeds, including any
   newly created categories.

## Notes

- Token is session-based, get a fresh one each invocation
- Feed IDs use format `feed/https://example.com/rss`
- The Fever API (`/api/fever.php`) is read-only, use GReader API for mutations
- URL-encode slashes in stream IDs when used in URL paths (`%2f`)
- `n=` controls batch size, `c=` is a continuation token (unix timestamp) for pagination
- To read full article content, use WebFetch on the article's `href`

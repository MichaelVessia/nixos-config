---
name: add-newsletter
description: Subscribe to an email newsletter via Kill the Newsletter and add the resulting feed to FreshRSS with auto-categorization. Use when user wants to subscribe to a newsletter, says "add newsletter", or provides an email-based newsletter to follow.
allowed-tools: Bash, WebFetch, AskUserQuestion
---

# Add Email Newsletter to FreshRSS

Subscribe to an email newsletter by creating a Kill the Newsletter inbox, then
adding the resulting Atom feed to FreshRSS with an appropriate category.

## Environment

- `FRESHRSS_URL` - Base URL of FreshRSS instance
- `FRESHRSS_API_USER` - API username
- `FRESHRSS_API_PASSWORD` - API password

## Procedure

### 1. Understand the newsletter

The user provides a newsletter name, signup page, or website. Use WebFetch on
the provided URL to understand what the newsletter covers (topic, audience,
content type). This informs both the feed title and category.

### 2. Create a Kill the Newsletter inbox

```bash
FEED_SLUG=$(curl -s -X POST https://kill-the-newsletter.com/feeds \
  -H "CSRF-Protection: true" \
  -d "title=NEWSLETTER_TITLE" \
  -D - -o /dev/null | grep -oP 'location:.*feeds/\K[^\s]+')
```

This gives you:
- Email: `${FEED_SLUG}@kill-the-newsletter.com`
- Atom feed: `https://kill-the-newsletter.com/feeds/${FEED_SLUG}.xml`

### 3. Authenticate with FreshRSS

```bash
AUTH_TOKEN=$(curl -s -X POST "$FRESHRSS_URL/api/greader.php/accounts/ClientLogin" \
  -d "Email=$FRESHRSS_API_USER" \
  -d "Passwd=$FRESHRSS_API_PASSWORD" | grep -oP 'Auth=\K.*')
```

### 4. Fetch existing categories

```bash
CATEGORIES=$(curl -s "$FRESHRSS_URL/api/greader.php/reader/api/0/tag/list?output=json" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" | jq -r '.tags[].id' | grep 'label/' | sed 's|user/-/label/||')
```

### 5. Infer category

Compare the newsletter content (from step 1) against existing categories. Pick
the best match. If no existing category fits, propose a short, lowercase name
consistent with the existing naming style.

Present the chosen category to the user with AskUserQuestion, showing existing
categories as options with the inferred pick marked "(Recommended)". Only skip
confirmation if the match is obvious.

### 6. Add the feed to FreshRSS

```bash
ATOM_URL="https://kill-the-newsletter.com/feeds/${FEED_SLUG}.xml"
RESULT=$(curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/quickadd" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "quickadd=$ATOM_URL")
FEED_ID=$(echo "$RESULT" | jq -r '.streamId')
curl -s -X POST "$FRESHRSS_URL/api/greader.php/reader/api/0/subscription/edit" \
  -H "Authorization: GoogleLogin auth=$AUTH_TOKEN" \
  -d "ac=edit" \
  -d "s=$FEED_ID" \
  -d "a=user/-/label/CATEGORY_NAME"
```

### 7. Output results

Print clearly:

- **Email address**: `${FEED_SLUG}@kill-the-newsletter.com`
- **Atom feed URL**: `https://kill-the-newsletter.com/feeds/${FEED_SLUG}.xml`
- **FreshRSS category**: the assigned category
- **What to do next**: Go to the newsletter's signup page, paste the email
  address above into the subscribe form, and submit. Once the newsletter sends
  its first email, it will appear as an entry in FreshRSS.
- If a confirmation email is required, it will also show up in FreshRSS as a
  feed entry. Follow the confirmation link from there.

## Notes

- The Kill the Newsletter inbox must be created before subscribing. The email
  address is what the user gives to the newsletter signup form.
- FreshRSS token is session-based, get a fresh one each invocation.
- Feed IDs use format `feed/https://...`
- Do not share the KTN feed URL publicly (anyone with it can send spam to it).

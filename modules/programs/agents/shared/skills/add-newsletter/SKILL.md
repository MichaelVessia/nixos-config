---
name: add-newsletter
description: Subscribe to an email newsletter via Kill the Newsletter and add the resulting feed to FreshRSS with auto-categorization. Use when user wants to subscribe to a newsletter, says "add newsletter", or provides an email-based newsletter to follow.
allowed-tools: Bash, WebFetch, AskUserQuestion, Skill
---

# Add Email Newsletter to FreshRSS

Subscribe to an email newsletter by creating a Kill the Newsletter inbox, then
adding the resulting Atom feed to FreshRSS with an appropriate category.

## Procedure

### 1. Understand the newsletter

The user provides a newsletter name, signup page, or website. Use WebFetch on
the provided URL to understand what the newsletter covers (topic, audience,
content type). This informs the feed title.

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

### 3. Add to FreshRSS

Invoke `add-feed` with the atom feed URL
(`https://kill-the-newsletter.com/feeds/${FEED_SLUG}.xml`) to authenticate with
FreshRSS, infer the best category, and add the feed.

### 4. Output results

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
- Do not share the KTN feed URL publicly (anyone with it can send spam to it).

---
name: freshrss
description: Read, search, and organize the personal FreshRSS library, including email newsletter subscriptions.
allowed-tools: Bash, WebFetch, AskUserQuestion
---

# FreshRSS

Search the personal Executor for FreshRSS. Use its tools for supported article and subscription operations. If the operation needs a direct API call, use the Google Reader API at `$FRESHRSS_URL/api/greader.php` with `FRESHRSS_API_USER` and `FRESHRSS_API_PASSWORD`. Get a session token from `accounts/ClientLogin` and send it as `Authorization: GoogleLogin auth=<token>`. Keep credentials and tokens out of logs and replies.

## Add a feed

1. List existing subscriptions and categories. Check for a duplicate.
2. Read the feed title, description, and recent posts. Select the best matching existing category. Confirm the choice if it is unclear. Propose a new category only if none fits.
3. Add the feed and assign the category. With the Google Reader API, use `subscription/quickadd` followed by `subscription/edit`.
4. Read the subscription back to verify its title and category.

## Subscribe to an email newsletter

1. Read the newsletter site and choose a title for its Kill the Newsletter inbox.
2. Create the inbox. Read the feed slug from the `Location` response header.

   ```bash
   curl -fsS -D - -o /dev/null https://kill-the-newsletter.com/feeds \
     -H 'CSRF-Protection: true' \
     --data-urlencode "title=${NEWSLETTER_TITLE}" |
     awk 'tolower($1) == "location:" { sub(/\r$/, "", $2); sub(/^.*\/feeds\//, "", $2); print $2 }'
   ```

3. Subscribe to `https://kill-the-newsletter.com/feeds/<slug>.xml` in FreshRSS and assign a category.
4. Share `<slug>@kill-the-newsletter.com`, the private Atom feed link, and the category only with the user in a private reply. Tell the user to enter the email address on the newsletter signup page. Look for confirmation messages in FreshRSS. Keep the private feed link out of public output.

## Organize uncategorized feeds

List subscriptions with no category or with only `Uncategorized`. Sample each feed and propose existing categories in one table with a short reason per feed. Leave feeds with insufficient evidence for review. For approved feeds, add the selected category and remove `Uncategorized`. Verify the changes and report the remaining uncategorized feeds.

## Recommend feeds

When asked for recommendations, use the current subscriptions to identify interests. Search for feeds the user does not already follow. Group the results by interest and provide each feed URL and a short description.

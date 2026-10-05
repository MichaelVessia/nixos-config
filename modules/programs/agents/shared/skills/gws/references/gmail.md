<!-- Adapted from googleworkspace/cli: frontmatter and skill routing removed; local links and authorization guidance updated. -->

# gmail (v1)


```bash
gws gmail <resource> <method> [flags]
```

## Helper Commands

| Command | Description |
|---------|-------------|
| [`+send`](gmail-send.md) | Send an email |
| [`+triage`](gmail-triage.md) | Show unread inbox summary (sender, subject, date) |
| [`+reply`](gmail-reply.md) | Reply to a message (handles threading automatically) |
| [`+reply-all`](gmail-reply-all.md) | Reply-all to a message (handles threading automatically) |
| [`+forward`](gmail-forward.md) | Forward a message to new recipients |
| [`+read`](gmail-read.md) | Read a message and extract its body or headers |
| [`+watch`](gmail-watch.md) | Watch for new emails and stream them as NDJSON |

## API Resources

### users

  - `getProfile` — Gets the current user's Gmail profile.
  - `stop` — Stop receiving push notifications for the given user mailbox.
  - `watch` — Set up or update a push notification watch on the given user mailbox.
  - `drafts` — Operations on the 'drafts' resource
  - `history` — Operations on the 'history' resource
  - `labels` — Operations on the 'labels' resource
  - `messages` — Operations on the 'messages' resource
  - `settings` — Operations on the 'settings' resource
  - `threads` — Operations on the 'threads' resource

## Discovering Commands

Before calling any API method, inspect it:

```bash
# Browse resources and methods
gws gmail --help

# Inspect a method's required params, types, and defaults
gws schema gmail.<resource>.<method>
```

Use `gws schema` output to build your `--params` and `--json` flags.

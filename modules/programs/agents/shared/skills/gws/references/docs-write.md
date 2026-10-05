<!-- Adapted from googleworkspace/cli: frontmatter and skill routing removed; local links and authorization guidance updated. -->

# docs +write


Append text to a document

## Usage

```bash
gws docs +write --document <ID> --text <TEXT>
```

## Flags

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--document` | ✓ | — | Document ID |
| `--text` | ✓ | — | Text to append (plain text) |

## Examples

```bash
gws docs +write --document DOC_ID --text 'Hello, world!'
```

## Tips

- Text is inserted at the end of the document body.
- For rich formatting, use the raw batchUpdate API instead.

> [!CAUTION]
> This is a **write** command — use the authorization rules in [the skill entry point](../SKILL.md).

## See Also

- [gws-shared](shared.md) — Global flags and auth
- [gws-docs](docs.md) — All read and write google docs commands

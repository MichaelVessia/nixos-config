# paperless-cli Reference

## search [query]

Full-text search. Query optional if using filters.

**Flags:**
- `--tag, -t <name>` - Filter by tag (repeatable)
- `--correspondent, -c <name>` - Filter by correspondent
- `--type, -d <name>` - Filter by document type
- `--after <date>` - Created after (YYYY-MM-DD or -Nd/-Nm/-Ny)
- `--before <date>` - Created before
- `--sort <field>` - Sort by: created, added, modified, title, correspondent, type
- `--limit, -l <n>` - Max results (default: 10, max: 100)
- `--json` - JSON output

## list

List recent documents.

**Flags:**
- `--inbox` - Show inbox documents only
- `--tag, -t <name>` - Filter by tag
- `--correspondent, -c <name>` - Filter by correspondent
- `--type, -d <name>` - Filter by type
- `--sort <field>` - Sort field (default: added)
- `--limit, -l <n>` - Max results
- `--json` - JSON output

## get <id>

Get document details and content.

**Flags:**
- `--content-only` - Only output text
- `--max-length, -m <n>` - Truncate content
- `--json` - JSON output

## download <id>

Download original document file.

**Flags:**
- `--output, -o <path>` - Save path
- `--force, -f` - Overwrite existing

## edit <id>

Edit document metadata.

**Flags:**
- `--title <value>` - Set title
- `--correspondent <name>` - Set correspondent
- `--type <name>` - Set document type
- `--no-correspondent` - Clear correspondent
- `--no-type` - Clear document type
- `--create` - Create correspondent/type if not found

## similar <id>

Find similar documents.

**Flags:**
- `--limit, -l <n>` - Max results (default: 5)
- `--json` - JSON output

## add-tag <document-id> <tag-name>

Add tag to document.

**Flags:**
- `--create` - Create tag if not found

## remove-tag <document-id> <tag-name>

Remove tag from document.

## tags

List all tags with document counts.

**Flags:**
- `--json` - JSON output

## correspondents

List all correspondents with document counts.

**Flags:**
- `--json` - JSON output

## types

List all document types with document counts.

**Flags:**
- `--json` - JSON output

## create-tag <name>

Create a new tag.

**Flags:**
- `--color <hex>` - Color
- `--is-inbox-tag` - Mark as inbox tag
- `--match <pattern>` - Match pattern
- `--matching-algorithm <algo>` - any, all, literal, regex, fuzzy
- `--is-insensitive` - Case-insensitive matching

## create-correspondent <name>

Create a new correspondent.

**Flags:**
- `--match <pattern>` - Match pattern
- `--matching-algorithm <algo>` - any, all, literal, regex, fuzzy
- `--is-insensitive` - Case-insensitive matching

## create-type <name>

Create a new document type.

**Flags:**
- `--match <pattern>` - Match pattern
- `--matching-algorithm <algo>` - any, all, literal, regex, fuzzy
- `--is-insensitive` - Case-insensitive matching

## stats

Show system statistics (document count, tags, correspondents, types).

**Flags:**
- `--json` - JSON output

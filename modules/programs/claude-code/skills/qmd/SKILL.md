---
name: qmd
description: Local semantic search for docs, notes, knowledge bases. Use when the user asks to search their notes, find documents, query their knowledge base, or needs context from their local markdown files.
allowed-tools: Bash, Read
---

# qmd - Local Document Search

Semantic + full-text search across local markdown docs using local LLMs.

## Search Commands

```sh
qmd search "query"    # BM25 full-text search
qmd vsearch "query"   # Semantic vector search
qmd query "query"     # Hybrid search with LLM reranking (best quality)
```

## Search Flags

| Flag | Purpose |
|------|---------|
| `-n <num>` | Limit results (default: 5) |
| `-c, --collection` | Restrict to specific collection |
| `--all` | Return all matches |
| `--min-score <num>` | Filter by relevance threshold |
| `--full` | Display complete document content |
| `--line-numbers` | Include line numbers |

## Output Formats

| Flag | Format |
|------|--------|
| `--files` | CSV: docid, score, filepath, context |
| `--json` | Structured JSON with snippets |
| `--csv` | Comma-separated values |
| `--md` | Markdown formatting |
| `--xml` | XML structure |

## Document Retrieval

```sh
qmd get "path/to/doc.md"      # Get specific document
qmd get "#abc123"             # Get by document ID
qmd multi-get "journals/*.md" # Get multiple docs by glob
```

## Collection Management

```sh
qmd collection list           # View all collections
qmd collection add ~/notes --name notes
qmd ls notes                  # List files in collection
qmd status                    # Index health
```

## Examples

```sh
# High-quality search with reranking
qmd query -n 10 "API design patterns"

# Full document content for LLM context
qmd search --md --full "error handling"

# Search specific collection
qmd search "meeting notes" -c work
```

## Workflow

1. Use `qmd collection list` to see available collections
2. Use `qmd query` for best search quality (uses LLM reranking)
3. Use `--full` when you need complete document content
4. Use `qmd get` to retrieve specific documents by path or ID

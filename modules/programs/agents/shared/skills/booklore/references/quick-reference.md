# BookLore Quick Reference

Common operations for quick copy-paste usage.

## Setup

`BOOKLORE_URL`, `BOOKLORE_USERNAME`, and `BOOKLORE_PASSWORD` are exported
into the shell by sops-nix via `modules/programs/shell.nix`. No `source`
step required.

```bash
echo "$BOOKLORE_URL"        # should print the LAN URL, e.g. http://192.168.1.7:8080
```

## Log in and stash the token

Every non-trivial call needs a JWT access token. Two patterns:

### One-shot (recommended for shell sessions)

```bash
TOKEN=$(curl -fsS -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"$BOOKLORE_USERNAME\",\"password\":\"$BOOKLORE_PASSWORD\"}" \
  "$BOOKLORE_URL/api/v1/auth/login" | jq -r .accessToken)
echo "${TOKEN:0:20}..."
```

### Also keep the refresh token

```bash
LOGIN=$(curl -fsS -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"$BOOKLORE_USERNAME\",\"password\":\"$BOOKLORE_PASSWORD\"}" \
  "$BOOKLORE_URL/api/v1/auth/login")
TOKEN=$(echo "$LOGIN" | jq -r .accessToken)
REFRESH=$(echo "$LOGIN" | jq -r .refreshToken)
```

### Refresh token (if the endpoint exists on this deployment)

```bash
# Verify the endpoint first — see troubleshooting.md.
TOKEN=$(curl -fsS -X POST -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH\"}" \
  "$BOOKLORE_URL/api/v1/auth/refresh" | jq -r .accessToken)
```

## System

### Version

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/version" | jq
```

### Who am I

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/users/me" | jq
```

## Libraries

### List libraries

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/libraries" \
  | jq '.[] | {id, name, paths}'
```

## Books

### List first 10 books

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books" \
  | jq '.[:10] | .[] | {id, title, authors, libraryId}'
```

### Count books

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books" \
  | jq 'length'
```

### Get one book

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books/142" | jq
```

### Group books by library

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books" \
  | jq 'group_by(.libraryId) | map({libraryId: .[0].libraryId, count: length})'
```

### Search by title (client-side)

This deployment has no confirmed server-side search. Filter in jq:

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books" \
  | jq --arg q "hail mary" '
      [.[] | select((.title // "") | test($q; "i"))
            | {id, title, authors, libraryId}]'
```

### Search by author (client-side)

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books" \
  | jq --arg q "weir" '
      [.[] | select(((.authors // []) | join(" ")) | test($q; "i"))
            | {id, title, authors}]'
```

## Shelves

### List shelves

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/shelves" | jq
```

## Workflows

### Workflow: login + summarize library

```bash
TOKEN=$(curl -fsS -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"$BOOKLORE_USERNAME\",\"password\":\"$BOOKLORE_PASSWORD\"}" \
  "$BOOKLORE_URL/api/v1/auth/login" | jq -r .accessToken)

echo "=== version ==="
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/version" | jq

echo "=== libraries ==="
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/libraries" \
  | jq '.[] | {id, name, paths: [.paths[].path]}'

echo "=== book count ==="
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books" \
  | jq 'length'
```

### Workflow: find a book and dump its full record

```bash
TOKEN=$(curl -fsS -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"$BOOKLORE_USERNAME\",\"password\":\"$BOOKLORE_PASSWORD\"}" \
  "$BOOKLORE_URL/api/v1/auth/login" | jq -r .accessToken)

ID=$(curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books" \
  | jq --arg q "hail mary" '
      [.[] | select((.title // "") | test($q; "i"))][0].id')

curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books/$ID" | jq
```

### Workflow: use the wrapper script

```bash
bash scripts/booklore.sh status
bash scripts/booklore.sh libraries
bash scripts/booklore.sh books 5
bash scripts/booklore.sh search "hail mary"
bash scripts/booklore.sh book-info 142
```

# Jellyfin Quick Reference

Common operations for quick copy-paste usage.

## Setup

`JELLYFIN_URL` and `JELLYFIN_API_KEY` are exported into the shell by sops-nix
via `modules/programs/shell.nix`. No `source` step required:

```bash
curl -s "$JELLYFIN_URL/System/Info" -H "X-Emby-Token: $JELLYFIN_API_KEY" | jq
```

Auth header is `X-Emby-Token` (Jellyfin reuses the Emby name).

## Server Status

```bash
curl -s "$JELLYFIN_URL/System/Info" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq '{ServerName, Version, ProductName, LocalAddress}'
```

Public reachability probe (no auth required):

```bash
curl -s "$JELLYFIN_URL/System/Info/Public" | jq
```

## Users

### List users

```bash
curl -s "$JELLYFIN_URL/Users" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq '.[] | {id: .Id, name: .Name, admin: .Policy.IsAdministrator, lastActive: .LastActivityDate}'
```

### Grab the first non-disabled user id (for `/Users/{id}/Items` calls)

```bash
USER_ID=$(curl -s "$JELLYFIN_URL/Users" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq -r '[.[] | select(.Policy.IsDisabled != true)] | .[0].Id')
```

## Libraries

```bash
curl -s "$JELLYFIN_URL/Library/VirtualFolders" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq '.[] | {name: .Name, type: .CollectionType, locations: .Locations}'
```

### Trigger a full library scan

```bash
curl -X POST "$JELLYFIN_URL/Library/Refresh" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY"
```

## Sessions

### All sessions (playing + idle)

```bash
curl -s "$JELLYFIN_URL/Sessions" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq '.[] | {user: .UserName, client: .Client, device: .DeviceName, nowPlaying: (.NowPlayingItem.Name // null)}'
```

### Only currently-playing

```bash
curl -s "$JELLYFIN_URL/Sessions" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq '[.[] | select(.NowPlayingItem != null) | {
      user: .UserName,
      device: .DeviceName,
      item: .NowPlayingItem.Name,
      series: (.NowPlayingItem.SeriesName // null),
      playMethod: .PlayState.PlayMethod,
      positionSeconds: (.PlayState.PositionTicks / 10000000),
      runtimeSeconds: (.NowPlayingItem.RunTimeTicks / 10000000)
    }]'
```

### Stop a session

```bash
curl -X POST "$JELLYFIN_URL/Sessions/$SESSION_ID/Playing/Stop" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY"
```

## Item Search

### Free-text search (Movies, Series, Episodes)

```bash
curl -s "$JELLYFIN_URL/Users/$USER_ID/Items?searchTerm=severance&Recursive=true&IncludeItemTypes=Movie,Series,Episode&Limit=25" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq '.Items[] | {name: .Name, type: .Type, series: (.SeriesName // null), year: .ProductionYear}'
```

### Recently added (per user, default 20)

```bash
curl -s "$JELLYFIN_URL/Users/$USER_ID/Items/Latest?Limit=10" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq '.[] | {name: .Name, type: .Type, series: (.SeriesName // null), year: .ProductionYear}'
```

### Limit to one library

```bash
# Get a parent library id from /Library/VirtualFolders -> .ItemId
curl -s "$JELLYFIN_URL/Users/$USER_ID/Items/Latest?Limit=10&ParentId=$LIBRARY_ID" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY"
```

## Library Counts

```bash
curl -s "$JELLYFIN_URL/Items/Counts" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" | jq
```

## Scheduled Tasks

### List

```bash
curl -s "$JELLYFIN_URL/ScheduledTasks" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq '.[] | {id: .Id, name: .Name, state: .State, lastResult: (.LastExecutionResult.Status // null)}'
```

### Run a task

```bash
curl -X POST "$JELLYFIN_URL/ScheduledTasks/Running/$TASK_ID" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY"
```

### Stop a running task

```bash
curl -X DELETE "$JELLYFIN_URL/ScheduledTasks/Running/$TASK_ID" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY"
```

## Workflows

### Workflow: who's watching what right now?

```bash
bash scripts/jellyfin.sh now-playing
```

Or raw:

```bash
curl -s "$JELLYFIN_URL/Sessions" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq '[.[] | select(.NowPlayingItem != null) | {user: .UserName, item: .NowPlayingItem.Name, device: .DeviceName}]'
```

### Workflow: spot-check a recent add

```bash
bash scripts/jellyfin.sh recently-added 5
bash scripts/jellyfin.sh item-search "<name from above>"
```

### Workflow: kick off a library scan and watch it finish

```bash
# 1. Find the "Scan Media Library" task id
TASK_ID=$(curl -s "$JELLYFIN_URL/ScheduledTasks" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq -r '.[] | select(.Key == "RefreshLibrary") | .Id')

# 2. Run it
curl -X POST "$JELLYFIN_URL/ScheduledTasks/Running/$TASK_ID" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY"

# 3. Poll status
curl -s "$JELLYFIN_URL/ScheduledTasks" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq '.[] | select(.Id == "'"$TASK_ID"'") | {state: .State, lastEnd: .LastExecutionResult.EndTimeUtc}'
```

### Ticks helper

Jellyfin times are 100-nanosecond ticks. Divide by `10000000` for seconds:

```bash
jq '.[] | {position: (.PlayState.PositionTicks / 10000000 | floor)}'
```

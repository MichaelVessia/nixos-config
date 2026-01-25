# How to Ralph

Quick guide to running autonomous coding tasks with Ralph.

## Prerequisites

- Claude Code CLI installed (`claude` command available)
- `jq` installed for JSON parsing
- Stories defined in `ralph/prd.json`

## Quick Start

```bash
# 1. Check what's in the queue
./ralph/scripts/prd-status.sh

# 2. Start the loop
./ralph/ralph.sh
```

That's it. Ralph picks the next pending story and starts working.

## Commands

| Command                                       | Description                         |
| --------------------------------------------- | ----------------------------------- |
| `./ralph/ralph.sh`                            | Run loop (default 10 iterations)    |
| `./ralph/ralph.sh 50`                         | Run loop with custom max iterations |
| `./ralph/scripts/prd-status.sh`               | Show PRD progress and next story    |
| `./ralph/scripts/prd-update.sh <id> <status>` | Manually update story status        |
| `./ralph/scripts/ci-check.sh`                 | Run CI checks manually              |

## Monitoring

```bash
# Watch progress in real-time
tail -f ralph/progress.txt

# Check PRD status
./ralph/scripts/prd-status.sh

# View agent output for iteration N
cat .ralph/iteration_N_output.txt
```

## Running Overnight

```bash
# Run in background with logging
nohup ./ralph/ralph.sh 100 > ralph-output.log 2>&1 &

# Check if still running
ps aux | grep ralph

# Stop if needed
pkill -f ralph.sh
```

## Story Lifecycle

```
pending -> in_progress -> complete
                       \> blocked (if stuck)
```

Ralph automatically:

1. Picks first pending story
2. Marks it `in_progress`
3. Runs Claude Code with the story prompt
4. Runs CI checks when Claude signals `STORY_COMPLETE`
5. Commits if CI passes, marks `complete`
6. Moves to next story

## Rollback

Each story = one atomic commit. Rollback is easy:

```bash
# See Ralph commits
git log --oneline --grep="Ralph-Iteration"

# Undo last story
git revert HEAD

# Undo specific story
git log --oneline --grep="Story: 1.2.0" | head -1 | cut -d' ' -f1 | xargs git revert

# Reset story status after rollback
./ralph/scripts/prd-update.sh 1.2.0 pending
```

## Adding Stories

Edit `ralph/prd.json` directly:

```json
{
  "id": "2.1.0",
  "phase": "Feature",
  "epic": "New Feature",
  "title": "Implement the thing",
  "description": "Detailed description of what to build",
  "acceptance_criteria": ["Criterion 1", "Criterion 2"],
  "specs": ["RELEVANT_SPEC.md"],
  "status": "pending",
  "estimated_complexity": "medium"
}
```

ID format: `phase.epic.story` (e.g., 1.2.3 = phase 1, epic 2, story 3)

Complexity: `small`, `medium`, `large`

## Troubleshooting

**Agent gets stuck:**

```bash
./ralph/scripts/prd-update.sh <id> blocked
# Add note to ralph/progress.txt explaining why
# Restart loop - it will skip blocked stories
```

**CI keeps failing:**

```bash
# Check what's failing
./ralph/scripts/ci-check.sh

# Fix manually, then restart
./ralph/ralph.sh
```

**Context window issues:**

- Break large stories into smaller ones
- Keep acceptance criteria focused

## Files

| File              | Purpose                            |
| ----------------- | ---------------------------------- |
| `prd.json`        | Stories and status                 |
| `progress.txt`    | Log of completed work              |
| `RALPH_PROMPT.md` | Prompt template sent to agent      |
| `.ralph/`         | Logs and debug output (gitignored) |

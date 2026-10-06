---
name: pstack-sync
description: Merge new upstream pstack releases into the vendored vessia skills in nixos-config without overwriting local customizations. Use when asked to sync, update, or check upstream pstack, or to compare vessia with upstream.
---

# pstack-sync

vessia is a vendored, renamed fork of upstream pstack at
`~/nixos-config/modules/programs/agents/vessia/`. Read its `README.md` first.
The script `scripts/pstack-sync` (beside this file) does a three-way merge:
base is the `rev` in `upstream.conf`, ours is the vendored tree, and theirs is
the new upstream revision. Base and theirs pass through `scripts/transform.pl`,
so the rename never shows up as a local change.

Your job is the part the script cannot do: understand both intents, keep
Michael's customizations, take upstream's improvements, and surface only the
calls that need his judgement.

## Steps

1. Work in `~/nixos-config` on master, per its `CLAUDE.md`. Run every command
   from the repo root. Leave unrelated local edits alone.
2. Preview: `<skill-dir>/scripts/pstack-sync --dry-run`. Add `--to <rev>` to
   target a revision other than upstream `main`. If the report has no upstream
   commits in scope, report that vessia is current and stop.
3. Read the upstream intent. For each commit in the report, read
   `git -C ~/.cache/pstack-sync/plugins.git show <sha> -- pstack cursor-team-kit`.
   Read the local intent with `pstack-sync --local-diff` and
   `git log -p -- modules/programs/agents/vessia/<path>` for each conflicting
   or customized path.
4. Apply: run the script without `--dry-run`. It refuses to run with
   uncommitted changes under the vendored tree. It writes merges in place,
   leaves `<<<<<<< local` / `>>>>>>> upstream` markers on conflicts, and moves
   `rev` in `upstream.conf`. `git diff` and `git checkout -- <vendored tree>`
   undo the whole sync.
5. Resolve each conflict by intent, not by side. Keep the local customization
   and fold in the upstream change when they are compatible. When they are
   not, keep the local version and add the item to the judgement list.
6. Work the **Needs judgement** section:
   - New upstream skill: it is vendored by default. Read it and say what it
     does. Recommend `drop <name>` if it duplicates a personal skill or
     conflicts with Michael's instructions.
   - New team-kit skill: not vendored. Recommend it only when it clearly fits.
   - Upstream removed a file you customized, or changed one you deleted:
     decide from the upstream commit whether the local change still has a
     home. If it does not, list it.
   - Possible rename or move: if a removed and an added file are the same
     content, port the local edits from the old path to the new one.
   - Name mismatch: add a rule to `transform.pl`, then rerun from a clean tree.
   - License change: always list it.
   - Unavailable tool: `upstream.conf` lists tools Michael does not have as
     `unavailable` lines, and the script flags new upstream lines that match.
     Rewrite the line to a tool he has when the swap is obvious (for example,
     a Grok model slug to the GPT Sol default). Otherwise list it. When a skill
     only exists for an unavailable tool, recommend `drop <name>`. If you find
     another tool he lacks, add an `unavailable` line for it.
7. Check what the merge brought in against Michael's instructions
   (`modules/programs/agents/shared/instructions.md`): new Cursor-only paths or
   tools, new model or provider defaults, or behavior that contradicts a rule.
   Adapt the vendored file when the fix is mechanical and obvious; list the
   rest. Look for new `pstack`/`poteto` spellings that the rename missed, and
   for URLs that the rename broke.
   Model defaults are a local rule: Opus (`claude-opus-5-5-high`) and GPT Sol
   (`gpt-6.1-sol-xhigh`) only. Michael has no Grok and does not use `max`
   effort. Rewrite any new upstream model slug, family list, or budget to fit
   that rule.
   Other local rules: PRs are GitHub PRs through `gh`, and stacks use GitHub's
   stacked PRs through `gh stack` (no Graphite or Origin). Review bots are
   generic AI reviewers (no Bugbot), and some repos have none. Parallel work
   runs as new agent threads that the current tool starts its own way (no
   Cursor cloud agents or `environment: "cloud"`); do not name a tool.
8. Verify:
   - `pstack-sync --scan` lists every remaining match for the `unavailable`
     tools. Compare it with the scan before the sync.
   - `grep -rnE '^(<<<<<<<|=======|>>>>>>>)' modules/programs/agents/vessia`
     prints nothing.
   - Every `skills/*/SKILL.md` `name:` matches its directory.
   - The Nix checks in `~/nixos-config/CLAUDE.md` pass for the root flake and
     `hosts/flomac/flake.nix`.
9. Commit only the vendored tree and any files you adapted, as
   `chore(vessia): sync upstream pstack to <short rev>`. List the upstream
   commits in the body.

## Report

- The upstream commit range and a short summary of what changed.
- The local customizations that survived, and how you merged each conflict.
- The judgement items, each with your recommendation and the alternative.
  Leave each item unchanged until Michael answers.

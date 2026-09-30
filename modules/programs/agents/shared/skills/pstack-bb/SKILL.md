---
name: pstack-bb
description: BB rules for pstack. Read it with pstack:poteto-mode before any pstack playbook. It states which rule wins where pstack conflicts with the fleet rules.
---

# pstack in BB

pstack is installed as the native plugin (`pstack:<skill>`). On Codex, also
read `pstack:poteto-mode` `references/codex-tools.md`. The shared
instructions win over pstack text. Until Michael decides otherwise:

| pstack text | Rule that wins now |
| --- | --- |
| Subagents (`Agent`, `spawn_agent`, `pstack:poteto-agent`, effort agents, panels in arena, interrogate, swarm, how, why, architect) | Do the step yourself, in sequence. For parallel writers, other models, or independent review, ask the owner for BB task threads. |
| File-writing delegates in their own worktrees (Feature, Orchestrate, swarm) | Follow the project's worktree rule. Do not create extra worktrees. |
| Autonomy "external actions (team chat, ticket updates) proceed without asking" | Send messages or write to shared systems only when the brief asks. |
| Shipping lands PRs | Stop at merge-ready. Michael merges. |
| Worktree cleanup deletes worktrees and simulators | List what to delete and ask. Delete nothing without approval. |
| "Broken skill mid-task, fix it in its own PR" | Report the defect to the owner. Do not open upstream PRs. |
| unslop, technical-writing, "Writing the reply" | Also apply ASD-STE100. Where they differ, STE wins. |
| no-comments findings | Keep the repo's comment practice. |
| Orchestrate and Autopilot | Only when the brief names them. The BB owner stays the coordinator. |
| `setup-pstack`, `pstack-models.md` | Do not edit the sheet. Nix owns it. |

Scripts run from the plugin root: `~/.local/share/pstack-claude/plugins/pstack`
(Claude Code) or `~/.codex/plugins/cache/pstack-claude/pstack/<version>`
(Codex). `gt` is not installed, so the Orchestrate stack frontier is not
available.

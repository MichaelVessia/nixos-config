---
name: pstack-bb
description: BB map for pstack. Read it with poteto-mode before any pstack playbook. It maps the omitted pstack skills, subagents, and tools to BB rules.
---

# pstack in BB

The shared instructions win over pstack text. Resolve a pstack relative link
from the skill directory (`~/.claude/skills/<skill>/` or
`~/.codex/skills/<skill>/`), not from its Nix store path.

| pstack names | Do this |
| --- | --- |
| Subagent, `Agent`, `spawn_agent`, `pstack:poteto-agent`, effort agents | Do the step yourself, in sequence. |
| `arena`, `swarm` (Feature 4, Eval 4-5, architect Phase B, blast-radius 6, figure-it-out) | Write two or more distinct candidates yourself, compare them, and record the choice. For parallel writers or other models, ask the owner for BB task threads. |
| `interrogate` (Feature 7, Bug fix 2-3, Opening a PR, architect Phase C) | `skip: owner review`. The owner starts an independent reviewer thread. |
| `unslop`, `technical-writing` | Write ASD-STE100 per the shared rules. |
| `no-comments`, `comment-sicko` | `skip: repo comment rule`. Match the repo's comment practice. |
| `babysit` skill; Babysit, Shipping, Autopilot, Orchestrate, Autonomous run, Worktree cleanup playbooks | Only when the brief names them. Opening a PR: post the URL and stop. |
| `tdd` (Bug fix 5) | Use `pstack-tdd`. |
| `setup-pstack`, `pstack-models.md`, Models sections | BB sets model and effort per thread. |
| `principle-never-block-on-the-human`, "full-autonomy grant" | The shared stop rules win. Put open decisions in your report. |
| `reflect`, `automate-me`, `recall` | `skip: not installed`. Put durable lessons in the Obsidian vault. |
| `typescript-best-practices` | Use `coding-standards`. |
| `plugin-dev:skill-development` | Use `writing-great-skills` if present, else the repo's skill rules. |
| `loop` | Run the check again yourself. |
| `AskUserQuestion` | Put the question in your report to the owner. |

Tools: `node` runs `poteto-mode/scripts/check-plan.mjs` (Multi-phase plan
step 6). `watch-pr` and `orch` need Bun to write `node_modules` into the
read-only Nix store, and `gt` is not installed. Only the Babysit, Shipping,
and Orchestrate playbooks use them. Otherwise write
`skip: needs writable scripts`.

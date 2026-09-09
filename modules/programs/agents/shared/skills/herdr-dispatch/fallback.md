# Provider-specific fallback

Reached from `herdr-dispatch` Assignment type. Recovery profiles, one per provider:

| Provider | Fallback launch |
|---|---|
| OpenAI | `--kind pi -- --model openai-codex/gpt-5.6-sol --thinking medium` |
| Anthropic | `--kind claude -- --model claude-opus-4-8 --effort high --dangerously-skip-permissions` |

- Fallback applies to failures observed during launch or submission, or to an explicitly requested later recovery. It never applies to background supervision after handoff.
- On a confirmed model-unavailable, unsupported-version, overload, or quota error, use the same-provider fallback once and report both the reason and the replacement. Never cross providers.
- Table-selected models are pre-authorized to fall back. An explicit user model or effort pin requires asking before substitution, unless the user also authorized fallback.
- If already on the fallback profile, or the fallback fails, stop and ask. Lowering effort does not restore exhausted quota; if the error confirms provider-wide exhaustion, report that instead of retrying the same provider.
- Authentication, permission, task, test, and ambiguous submission failures are not fallback triggers. Diagnose them; do not reroute or duplicate work.
- Before resuming failed work on a fallback, confirm the original worker is no longer working. Preserve its diff and report, and hand off the remaining task, not the original prompt. If stopping it requires authority not already granted, ask. Never leave two writers active.

## Known environment gotcha

Fable 5.1 requires Claude Code 2.1.251 or newer. Check the Claude executable resolved in the destination launch environment, not just the sending shell: a stale `~/.npm-global/bin/claude` can shadow the newer Nix-managed binary. If the destination binary is older, use the Anthropic fallback until upgraded. Do not update the installed CLI automatically. CLI compatibility does not prove account access.

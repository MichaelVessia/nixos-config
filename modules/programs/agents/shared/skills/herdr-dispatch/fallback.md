# Fallback

- If an unpinned Opus implementation assignment cannot launch because Opus is
  unavailable, use `--kind omp -- --model openai-codex/gpt-6.1-sol --thinking medium`
  once. Confirm the first worker is no longer running. Give the replacement the
  remaining goal, context, scope, and completion condition.
- An explicit provider, model, or effort pin requires asking before substitution,
  unless the user authorized fallback. Do not reroute review or investigation
  assignments automatically.
- Authentication, permission, task, test, and ambiguous submission failures are
  not model fallback triggers. Diagnose and report them. Never leave two writers
  active.

## Known environment gotcha

Fable 5.1 requires Claude Code 2.1.251 or newer. Check the Claude executable
resolved in the destination launch environment, not just the sending shell: a
stale `~/.npm-global/bin/claude` can shadow the newer Nix-managed binary. If the
destination binary is older, report the compatibility issue and use only an
explicitly authorized alternative. Do not update the installed CLI automatically.

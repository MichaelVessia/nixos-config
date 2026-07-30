# Fresh-context review gate

Launch a new read-only reviewer for each candidate PR before it opens. It receives the task contract and the candidate worktree, but not the owner's reasoning or claimed success.

```text
Review this candidate branch as a fresh-context gate. Read only; do not edit, commit, push, or open a PR.

Task: <task>
Objective: <caller-visible outcome>
Acceptance criteria:
- <criterion>

Candidate worktree: <path>
Base branch: <base>
Required validation: <commands>
Known constraints: <repository and user constraints>

Verify independently:
1. The diff satisfies every acceptance criterion and does not change unrelated behavior.
2. The implementation exercises the intended production path rather than a parallel or dead path.
3. Tests defend the observable contract and would fail for a plausible regression; they do not merely execute code or duplicate existing coverage.
4. Error handling, types, security boundaries, compatibility, and migrations match repository policy.
5. Validation evidence is reproducible from this worktree.
6. No generated files, debug artifacts, broad formatting, hidden product changes, or unexplained dependencies slipped in.

Return findings ordered by severity with file/symbol evidence and a concrete failure mode. Separate blockers from optional improvements. If clean, say `GATE: PASS` and list the checks you independently ran. If not, say `GATE: FAIL`.
```

The parent routes findings to the existing owner. A reviewer finding is evidence to evaluate, not an automatic instruction: reject incorrect or out-of-scope suggestions with a reason. Repeat with fresh context after material repairs.

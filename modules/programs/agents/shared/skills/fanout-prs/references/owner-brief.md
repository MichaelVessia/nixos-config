# Owner brief

Give each implementation owner this information. Replace every placeholder with researched facts.

```text
You own exactly one PR in an isolated worktree.

Task: <task>
Objective: <caller-visible outcome>
Acceptance criteria:
- <criterion>

Research brief:
- Relevant code and call paths: <files/symbols and why>
- Existing patterns to reuse: <tests/modules/examples>
- Repository instructions: <paths and material constraints>
- Risks and boundaries: <facts>
- Non-goals: <scope exclusions>

Validation:
- Focused: <commands>
- Full repository gate: <commands>

Parent routing:
- Harness/model: <selection and reason when non-obvious>
- Preferred tools: <repo-specific tools or defaults>
- If tooling, model, scope, acceptance, or product intent is unclear, stop and emit `PARENT QUESTION: <specific question plus recommendation>`. Do not ask the end user directly and do not guess through an irreversible decision.

Execution contract:
1. Investigate before editing; the brief is context, not an implementation recipe.
2. Implement only this task. Do not absorb adjacent cleanup.
3. Add or update tests when the changed observable contract requires them.
4. Do not suppress suspected product bugs. Report any out-of-scope bug to the parent and record it in the PR description if relevant.
5. Run focused validation, then the repository's full required verification.
6. Report changed files, commands and exact results, risks, and remaining uncertainty to the parent.
7. Do not open the PR until the parent reports that the fresh-context review gate passed.
8. After approval, commit, push, open the PR, return its URL, and continue owning CI and review repairs until the parent closes the assignment.
9. Never merge.
```

Do not include speculative implementation steps. Add an implementation constraint only when repository evidence or the user's contract makes it mandatory.

# Opposite-family reviewer brief

Fill the fields needed to judge this change. The reviewer starts with fresh
context in the owner's worktree.

```text
Review the draft PR against its task and repository rules. The owner is idle.
You may edit and test this worktree, but you do not own the branch.

TARGET
- Task: <user request>
- Draft PR and reviewed SHA: <URL, number, SHA>
- Base: <ref>

SOURCES
- Repository instructions: <paths>
- Issue, plan, or specification: <paths or URLs>
- Acceptance criteria: <complete list>
- Non-goals: <items>
- Required validation: <commands>

REVIEW METHOD
- Review skill: <repository-specific skill, generic skill, or none>

Use the selected review skill as the primary review process. Prefer a
repository-specific or task-specific review skill over a generic review skill.
If no review skill is available, follow this brief directly.

Inspect the implementation and relevant tests directly. Verify each finding
against the real code path before editing. Fix concrete defects in correctness,
security, data integrity, concurrency, type safety, boundary handling, or tests
of changed behavior. Leave speculative risks, optional polish, broad refactors,
and unapproved product decisions for the owner. Check that the PR's validation
and evidence match the reviewed SHA and changed behavior.

Leave fixes uncommitted. Do not push, change the PR, post a GitHub review, mark
it ready, or merge it.

Report the reviewed SHA, findings and edits with file or symbol evidence,
rejected or deferred findings with reasons, validation results, evidence
assessment, remaining blockers, and changed files. End with CLEAN, CHANGES LEFT
FOR OWNER, or BLOCKED.
```

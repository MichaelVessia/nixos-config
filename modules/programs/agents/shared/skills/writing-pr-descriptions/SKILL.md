---
name: writing-pr-descriptions
description: Use when writing or editing a pull request title, body, or PR description.
---

# Writing pull requests

Give reviewers the shortest useful explanation of the final change. Prefer
concrete evidence over an essay or a checklist of work performed.

## Ground the description

- Read the repository's PR template and contribution instructions first. Honor
  required sections; the defaults below apply where the repository is silent.
- Inspect the aggregate diff against the PR's target branch, not just the latest
  commit. Describe what would land in the final squash merge.
- Explain the problem, the resulting behavior, and any non-obvious trade-off.
  Do not narrate intermediate commits, review iterations, or abandoned refactors.
  A PR shrinking from 6,000 lines to 1,000 is not part of the shipped change.
- Only claim behavior, measurements, or evidence you have verified. Do not invent
  benchmarks, screenshots, links, or test results.

## Title and body

- Use a short, specific title describing the outcome. Follow repository title
  conventions; avoid vague titles such as "improvements" or "misc fixes".
- Default to a few concise bullets. Skip empty headings and boilerplate sections.
- Do not add routine "Validation", "Tests run", or "I ran tests" lists unless
  required. Still disclose meaningful validation gaps, known failures, rollout
  risks, breaking changes, and migration requirements.
- Use focused code snippets, sample usage, and Mermaid code blocks when they
  explain behavior or structure more clearly than prose. Do not add diagrams
  merely for decoration. Use `/show-me` when a visual would genuinely help
  reviewers understand the change; skip it when prose or a small snippet suffices.
- Link relevant issues and useful code references rather than copying long
  implementation details into the body.

## Show the evidence

- For visual changes, including indirectly affected UI, show a before/after table
  with uploaded images or videos. Label states and keep viewport, data, and other
  comparison conditions consistent. If captures are unavailable, say so rather
  than implying a visual comparison was performed.
- For performance claims, show a before/after benchmark table: the baseline is
  the target branch and the candidate is the PR. Include units, workload,
  measurement conditions, and enough repetition or uncertainty information to
  avoid presenting noise as an improvement. Without measurements, describe the
  intended effect, not a proven speedup.
- Keep evidence proportional to the change. A small internal fix need not carry
  screenshots, benchmarks, or a diagram.

## When more detail is justified

For unusually difficult, high-risk, or broad changes, a longer technical narrative
is appropriate: context, approach, trade-offs, and concrete examples or diagrams.
Length must earn its place by helping review, not by documenting every step taken.

Before publishing, check that the description matches the final diff and that all
links and media work. Writing a draft does not itself authorize posting or updating
it on GitHub.

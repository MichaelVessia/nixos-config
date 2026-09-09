---
name: plannotator-compound
disable-model-invocation: true
description: Analyze denied plans in a Plannotator archive or Claude Code logs and produce an HTML report with evidence-based prompt improvements.
---

# Planning feedback analysis

Produce a versioned HTML report of denial patterns and specific prompt changes.
Complete the analysis, generate the report, and open it for the user.

## Select source and scope

Use `$PLANNOTATOR_DATA_DIR/plans/`, defaulting to `~/.plannotator/plans/`,
when it contains `*-denied.md` files. Otherwise, read
[claude-code-fallback.md](references/claude-code-fallback.md) for the bundled
transcript parser, provenance rules, and alternative metrics. Ask for a source
directory only if neither source is available.

Honor a requested date range. Otherwise analyze the full archive. A request to
update a previous report can use records after its cutoff date; state the range
and retain overall inventory counts. Preserve existing reports by using
`compound-planning-report.html`, then `-v2.html`, `-v3.html`, and so on.

## Evidence and analysis

For Plannotator data, count approved and denied files, dates, and approved-plan
line counts. Compute revision rate as denied / (approved + denied). Read every
denied file in scope. Do not count annotations or diff files again: denied files
already contain the plan and feedback.

For each denied plan, retain its source, date, topic, actual feedback, requested
changes, and annotations. Reconcile processed counts with the inventory.
Choose direct processing or batches based on context size. Delegate only when
available and authorized; honor explicit model choices. The analysis must also
work without subagents.

Derive categories from the evidence. Report category counts and percentages,
recurring requests and phrases, changes over time, and specific prompt
instructions. Link conclusions to source examples. Distinguish inferred
preferences from explicit requests, and avoid claiming that denied-plan data
proves which plans succeeded.

Calculate the share of denials addressed by the proposed instructions. Count
each denial once in that coverage figure. Label it as an estimate of coverage,
not a measured reduction in future denials. Report sparse or missing evidence
without inventing categories or examples.

## Deliver

Read [report.md](references/report.md) for the HTML template, visual defaults,
and source-specific presentation. Use actual counts and quotes. Check the
report's displayed metrics and copy button. Save it in the plans directory,
open it, and report its path, scope, principal findings, and limitations.

If persistent planning instructions are requested, use
[improvement-hook.md](references/improvement-hook.md). An analysis request alone
does not authorize installation of a hook.

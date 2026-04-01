---
name: diataxis-documentation
description: Use when writing, restructuring, or reviewing technical documentation and you need to decide between tutorial, how-to, reference, and explanation styles.
---

# Writing Documentation with Diataxis

Apply the Diataxis framework to keep documentation aligned to one user need at a time. The core distinction is two axes:

- Action vs cognition
- Acquisition vs application

Those axes produce four documentation types:

| User Need | Documentation Type |
|-----------|--------------------|
| Learning by doing | Tutorial |
| Achieving a task while working | How-to guide |
| Looking up facts while working | Reference |
| Building understanding | Explanation |

## The Compass

When the right doc type is unclear, ask:

1. Is this content mainly about action or cognition?
2. Is the reader learning or applying skill?

Use the answers to place the content in one quadrant:

| Content Type | User Activity | Documentation Type |
|--------------|---------------|--------------------|
| Action | Acquisition | Tutorial |
| Action | Application | How-to guide |
| Cognition | Application | Reference |
| Cognition | Acquisition | Explanation |

## Type Boundaries

### Tutorials

Use tutorials for guided learning by doing.

- Own the learner's success, every step should work
- Choose one concrete path, no alternatives
- Minimise explanation, link out instead
- Deliver visible results early and often
- Tell the learner what to notice

### How-to Guides

Use how-to guides for competent users solving real problems.

- Focus on goals, not tool surfaces
- Assume competence, don't teach fundamentals
- Prefer flow over completeness
- Handle real-world complexity with conditionals
- Title clearly as "How to ..."

### Reference

Use reference for factual lookup during work.

- Describe, don't instruct
- Mirror the product structure
- Be consistent, neutral, and complete
- Document parameters, return values, constraints, exceptions
- Examples should illustrate, not teach

### Explanation

Use explanation for understanding and context.

- Answer "why"
- Discuss trade-offs, history, constraints, alternatives
- Connect related concepts
- Keep instruction and low-level lookup detail out
- Permit perspective and opinion where useful

## Writing Workflow

1. Identify the reader's immediate need.
2. Pick one Diataxis type with the compass.
3. Remove content that serves a different need.
4. Split mixed content into separate docs when necessary.
5. Cross-link between docs instead of collapsing them together.

## Review Workflow

When reviewing existing docs:

1. Pick a page, section, or paragraph.
2. Ask what user need it serves.
3. Confirm which Diataxis type it should be.
4. Fix the most obvious mismatch first.
5. Repeat.

## Common Mistakes

- Mixing tutorials and how-to guides, the most common failure
- Over-explaining in tutorials
- Teaching basics in how-to guides
- Instructing in reference docs
- Hiding explanation inside action-oriented docs
- Creating empty sections just to satisfy the four categories

## Practical Rules

- Structure follows content, not the other way around
- Each document should primarily serve one user need
- Split and link when one page tries to do multiple jobs
- Use British English spelling when applying this skill
- Never label a document with its Diataxis type in the title, subtitle, or opening line (no "This page is a reference", "Explanation: ...", etc.). The type should shape the writing style, not appear as a visible tag.

## Detailed Guidance

- [Principles](./references/principles.md) for deeper rules and examples by doc type
- [Quality and Complex Scenarios](./references/quality-and-scenarios.md) for quality criteria, boundary cases, and large-doc-set structure

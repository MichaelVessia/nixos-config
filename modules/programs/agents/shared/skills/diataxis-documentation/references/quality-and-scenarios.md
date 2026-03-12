# Quality and Complex Scenarios

This file covers how Diataxis applies to larger documentation sets and messy real-world situations.

## Two Kinds of Quality

### Functional quality

These qualities are objective constraints:

- Accuracy
- Completeness
- Consistency
- Precision
- Usefulness

Diataxis does not create functional quality. It only makes gaps easier to spot.

### Deep quality

These qualities are felt in use:

- Flow
- Anticipation
- Fitness for the reader's need
- Coherence

Diataxis is primarily about enabling this second kind of quality.

## Important Limits

Diataxis will not:

- Make documentation accurate by itself
- Replace domain expertise
- Remove the need for iteration and user testing
- Solve organisational or resourcing problems

It is a framework for form and fit, not a substitute for technical truth.

## Complex Structures

### Diataxis is not a four-box template

Do not force every feature into tutorial, how-to, reference, and explanation just for symmetry. Provide only what users actually need.

### Multiple user groups

End users, integrators, and maintainers may effectively need different documentation systems. Structure around their actual paths, not around one rigid hierarchy.

### Multiple environments

If workflows differ substantially across environments, separate the docs where necessary. Shared content can stay shared.

### Landing pages

Landing pages should orient, not just list links. Add short introductions and group long lists into smaller clusters.

### Long lists

Lists longer than about seven items get hard to scan unless they have a mechanical order. Group them.

### Structure depth

Keep structure shallow where possible. Extra nesting makes navigation harder.

## Boundary Problems

### Tutorial vs how-to

This is the most common confusion.

Tutorial:

- Study
- Guided path
- Few or no choices
- Teacher owns success

How-to:

- Work
- Real-world problem solving
- Conditional choices
- Reader owns execution

The distinction is not beginner vs advanced. It is learning vs applying.

### Reference vs explanation

Reference:

- Consulted during work
- Lists facts
- Neutral and direct

Explanation:

- Read for understanding
- Explores rationale and context
- Can include perspective

If the reader would likely open it while actively working, it is probably reference. If they would read it to build a model in their head, it is probably explanation.

## Iterative Improvement

Use Diataxis incrementally:

1. Pick one page or section.
2. Decide what user need it should serve.
3. Fix the strongest mismatch.
4. Repeat.

Do not wait for a perfect restructure plan. Structure can emerge from repeated local improvements.

## Minimal Documentation Sets

Not every product or feature needs all four types. Sometimes the right set is:

- Reference only
- How-to plus reference
- Tutorial plus reference

Ship the smallest useful set that serves real needs well.

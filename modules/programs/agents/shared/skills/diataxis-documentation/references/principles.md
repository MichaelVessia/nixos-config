# Detailed Principles for Each Documentation Type

This file provides deeper guidance for each Diataxis documentation type.

## Tutorials

Tutorials are lessons. They help learners acquire competence and confidence through doing.

### Core principles

#### 1. The teacher owns success

If the learner gets stuck, the tutorial failed. The learner's job is to follow along, not recover from gaps.

The tutorial should be:

- Meaningful
- Successful
- Logical
- Usefully complete

#### 2. Minimise explanation

Learning happens through action. Explanation interrupts momentum.

- Give only the context needed to keep the learner moving
- Link to explanation docs for the deeper why
- Resist the urge to front-load theory

#### 3. Stay concrete

Prefer one specific path:

- This problem
- This command
- This result

Avoid options, abstractions, and alternatives.

#### 4. Produce visible results early

Each step should give feedback:

- A file exists
- A command succeeds
- A page changes
- A service starts

Visible progress builds confidence and helps learners connect cause and effect.

#### 5. Maintain expectation

Tell the learner what should happen:

- "You should see ..."
- "Notice that ..."
- "If you do not see ..., you probably missed ..."

Show expected output when possible.

#### 6. Point out what matters

Learners often miss the signal while concentrating on the mechanics. Tell them what to notice and why it matters.

#### 7. Aim for the feeling of doing

Good tutorials create rhythm. Purpose, action, and result should move together cleanly.

#### 8. Ignore alternatives

Pick one route and stick to it. Save choices for later docs.

#### 9. Optimise for reliability

If a learner follows the steps, the tutorial should work. Reliability matters more than breadth.

## How-to Guides

How-to guides help competent users solve real problems while working.

### Core principles

#### 1. Start from the goal

Write for meaningful outcomes, not feature tours.

Good:

- "How to deploy with zero downtime"
- "How to configure automated backups"

Bad:

- "Deploy command"
- "Backup options"

#### 2. Assume competence

The reader already knows the domain and wants to get something done. Don't reteach the basics.

#### 3. Seek flow

Keep the guide aligned to the user's working rhythm.

- Group related operations
- Reduce context switching
- Anticipate the next thing the reader will need

#### 4. Reflect real-world complexity

Use conditional guidance where needed:

- "If you need X, do Y"
- "For production, also configure Z"

#### 5. Omit the unnecessary

Practical usefulness beats exhaustiveness. Link to reference instead of listing every option inline.

#### 6. Focus on tasks, not tools

Tools matter only as far as they help accomplish the task.

#### 7. Use a logical sequence

Order should make sense for human action, not just for system dependencies.

#### 8. Name guides clearly

Titles should say exactly what the guide helps the reader do.

## Reference

Reference describes the system for users who need facts while working.

### Core principles

#### 1. Describe only

Reference should state:

- What something is
- What it does
- How it behaves
- Which options and constraints apply

Do not instruct. Do not explain why.

#### 2. Mirror the product

The reference structure should match the product structure so readers can navigate by the same mental model.

#### 3. Be consistent

Use stable patterns across entries. Readers should know where to look for parameters, return values, examples, constraints, and warnings.

#### 4. Be austere and authoritative

Reference is for consultation, not persuasion. Keep tone factual and unambiguous.

#### 5. Prefer completeness

Missing facts make reference untrustworthy. Cover the whole surface area that users will consult.

#### 6. Use examples carefully

Examples should illustrate normal usage without turning into task instruction.

## Explanation

Explanation exists to deepen understanding.

### Core principles

#### 1. Talk about the subject

Explanation should widen the reader's view. It is not task guidance.

#### 2. Answer why

Use explanation for:

- Design rationale
- Trade-offs
- History
- Constraints
- Comparisons

#### 3. Make connections

Help the reader relate concepts to each other and to the wider system.

#### 4. Provide context

Historical, organisational, architectural, or conceptual context all belong here when they improve understanding.

#### 5. Allow perspective

Explanation can include opinion and competing viewpoints, as long as it remains honest and bounded.

#### 6. Protect the boundary

When explanation starts teaching steps or listing exhaustive facts, split that material into how-to or reference docs.

#### 7. Take a wider view

Explanation should sit above the immediate task and help the reader reason better later.

---
name: deslop
description: Review text or code comments for AI writing tropes and suggest fixes. Use when writing prose, documentation, PR descriptions, or commit messages.
---

# Deslop

Review the given text (or your own draft output) for AI writing tropes and
rewrite to remove them. If no text is provided, review your most recent prose
output in the conversation.

## Tropes to detect and fix

### Word choice

- **Magic adverbs**: "quietly", "deeply", "fundamentally", "remarkably",
  "arguably" used to inject false significance.
- **Delve and friends**: "delve", "certainly", "utilize", "leverage" (as verb),
  "robust", "streamline", "harness".
- **Ornate nouns**: "tapestry", "landscape", "paradigm", "synergy",
  "ecosystem", "framework" where simpler words work.
- **"Serves as" dodge**: replacing "is" with "serves as", "stands as", "marks",
  "represents".

### Sentence structure

- **Negative parallelism**: "It's not X, it's Y" and variants ("not because X,
  but because Y", "The question isn't X. The question is Y.").
- **Dramatic countdown**: "Not X. Not Y. Just Z."
- **Self-posed rhetorical Q&A**: "The result? Devastating." / "The worst part?
  Nobody saw it coming."
- **Anaphora abuse**: repeating the same sentence opening 3+ times in
  succession.
- **Tricolon abuse**: back-to-back rule-of-three constructions.
- **Filler transitions**: "It's worth noting", "It bears mentioning",
  "Importantly", "Interestingly", "Notably".
- **Superficial analyses**: tacking "-ing" phrases onto sentences for shallow
  commentary ("highlighting its importance", "reflecting broader trends").
- **False ranges**: "from X to Y" where X and Y aren't on a real scale.

### Paragraph structure

- **Short punchy fragments**: excessive one-sentence paragraphs for
  manufactured emphasis.
- **Listicle in a trench coat**: numbered points disguised as prose ("The
  first... The second... The third...").

### Tone

- **False suspense**: "Here's the kicker", "Here's the thing", "Here's where
  it gets interesting".
- **Patronizing analogy**: "Think of it as...", "It's like a...".
- **Futurism invite**: "Imagine a world where...".
- **False vulnerability**: performative self-awareness or honesty.
- **"The truth is simple"**: asserting clarity instead of demonstrating it.
- **Stakes inflation**: inflating everything to world-historical significance.
- **Pedagogical voice**: "Let's break this down", "Let's unpack this", "Let's
  explore".
- **Vague attributions**: "Experts argue", "Industry reports suggest" without
  naming sources.
- **Invented concept labels**: compound labels like "supervision paradox",
  "acceleration trap" used as if established terms.

### Formatting

- **Em-dash addiction**: overuse of em dashes for dramatic pauses and pivots.
  (Use commas, parentheses, or periods instead.)
- **Bold-first bullets**: every list item starting with a bolded keyword.
- **Unicode decoration**: smart quotes, unicode arrows where straight
  quotes and `->` / `=>` would do.

### Composition

- **Fractal summaries**: summarizing at every level (subsection, section,
  document).
- **Dead metaphor**: beating one metaphor across the entire piece.
- **Historical analogy stacking**: rapid-fire listing of companies or tech
  revolutions for false authority.
- **One-point dilution**: restating a single argument 10 ways across thousands
  of words.
- **Signposted conclusion**: "In conclusion", "To sum up", "In summary".
- **"Despite its challenges..."**: acknowledging problems only to immediately
  dismiss them.

## Process

1. Read the text carefully.
2. Flag each trope instance with the specific trope name and the offending
   passage.
3. Provide a rewritten version of each flagged passage.
4. If reviewing a full document, provide a clean rewritten version at the end.

## Rules

- One instance of a trope can be fine. Flag when multiple tropes cluster or one
  repeats.
- Preserve the author's meaning and voice. Fix the slop, not the ideas.
- Prefer concrete, specific language over vague abstractions.
- Varied sentence length and structure is good. Imperfection is good.

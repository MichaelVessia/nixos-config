# Report design

Use the existing template as the default design. Adapt section counts and presentation to the available evidence and user instructions. References to Phase 3 mean the completed analysis.

## Phase 4: Generate the HTML Dashboard

Build a single, self-contained HTML file as the final deliverable. Save it to
the user's plans directory with a versioned filename:

- First ever report: `compound-planning-report.html`
- Second report: `compound-planning-report-v2.html`
- Third report: `compound-planning-report-v3.html`
- And so on.

Determine the version number from existing reports without overwriting them.

**If this is an incremental report**, the header should indicate the analysis
period (e.g., "March 15 – March 31, 2026") and include a subtitle noting
"Incremental analysis — see v{N-1} for earlier findings." The narrative in
section 1 should frame findings as what's new or changed since the last report,
not as a complete picture. Overall stats in the header (file counts, revision
rate) should still reflect the full archive for context.

Read the template at `../assets/report-template.html` for the **design language
only**. The template contains example data from a previous analysis — ignore all
data values, quotes, and percentages in the template. Use only its visual design:
colors, typography, spacing, component styles, and layout patterns.

### Design Language (from template)

- **Palette:** Light mode, warm off-white (#FDFCFB), text in slate scale, amber
  for highlights/accents, emerald for positive, rose for negative, indigo for
  action elements
- **Typography:** Playfair Display (serif, for narrative headings), Inter (sans,
  for body/data), JetBrains Mono (mono, for code/phrases) — Google Fonts CDN
- **Layout:** Single-column, max-width 1024px, generous vertical whitespace (128px
  between major sections), editorial/narrative-first aesthetic
- **Tone:** Calm, reflective, authoritative. Like a personal retrospective journal,
  not a monitoring dashboard.

### Page Frame (header + footer)

Before the 7 sections, the page has:

- **Header:** Report title on the left (Playfair Display, ~36px), project name +
  date range below it in light meta text. On the right: file counts in mono
  (e.g., "223 denials · 71 days"). Separated from content by
  a bottom border. Generous bottom padding before section 1.

- **Footer:** After section 7. Top border, centered italic Playfair Display tagline
  summarizing the corpus (e.g., "Analysis of X denied plans from the Plannotator
  archive.").

### Dashboard Section Order (7 sections)

The report follows this exact section order. Each section builds on the previous
one. The sections progress from results, to causes, to actions:

1. **The main finding** — An editorial paragraph (Playfair Display
   serif, ~26px) that states the main finding. Do not use bullet points. Alongside it, a KPI
   sidebar with 3 key metrics (the top denial percentage, the overall revision
   rate, and the number of distinct denial categories found). Use an amber inline
   highlight on the most important number in the paragraph.

2. **Why plans get denied** — The taxonomy as a ranked list. Each row: rank number
   (mono), category label, a thin 4px progress bar (top item in amber-500, rest
   in slate-300), percentage (mono), and for the top entries, a real italic quote
   from the data below the label. Show the top 10 categories or however many the
   data supports (minimum 5).

3. **How expectations evolved** — One card per natural time period. Each card has:
   the period name in serif, a theme phrase in colored uppercase (different color
   per period to show progression), a description paragraph, and a stat line at
   the bottom (e.g., "X denials · Y narrative requests"). If the data spans less
   than 3 distinct periods, use 2 cards or even a single card with internal
   progression noted.

4. **What works vs what doesn't** — Two side-by-side cards. Left: green-tinted
   (emerald-50/50 bg, emerald-100 border) with traits of plans that succeed for
   this reviewer. Right: red-tinted (rose-50/50 bg, rose-100 border) with what
   agents keep getting wrong. Both derived from the reduction analysis. Bulleted
   with small colored dots. 5-8 items per card.

5. **Recommended changes** — Open with a Playfair
   Display narrative sentence stating how many prompt instructions were derived
   and what estimated percentage of denials they address (use the real calculated
   percentage from Phase 3, not a generic number). Then the top 3 most impactful
   improvements as numbered items, each with an amber number, bold title, and
   one-line description. This section bridges the analysis and the full prompt
   that follows.

6. **Your most-used phrases** — Grid of chips (2-col mobile, 3-col desktop). Each
   chip: monospace quoted phrase on the left, frequency count on the right. White
   bg, slate-200 border, rounded-12px. Show 9-12 of the most recurring phrases
   found. Use the reviewer's exact words.

7. **The corrective prompt** — Dark panel (slate-900 bg, white text, rounded-3xl,
   shadow-xl). Opens with a Playfair intro sentence about the instructions. Then
   a dark code block (slate-800/80 bg, amber-200 monospace text) containing the
   full numbered prompt instructions from Phase 3. Include a copy-to-clipboard
   button that works (JS included). Below the code block: a gradient glow card
   (indigo-to-purple blurred halo behind a white card) with a closing message
   that these instructions are personal — derived from the user's own feedback,
   their own language, their own standards.

### Adaptation Rules

- If the user has < 3 months of data, reduce the evolution section to fewer cards
- If most denied files lack feedback below the `---` (bare denials with no
  annotations), note this in the narrative — the analysis will be thinner
- **Claude Code fallback mode:** Explicitly label the report source as Claude Code
  `ExitPlanMode` denial reasons. Do not fabricate Plannotator-only fields such as
  annotation counts or approved-plan line counts. See the fallback reference for
  KPI substitutes and footer/provenance guidance.
- If fewer than 5 denial categories emerge, combine the taxonomy and patterns
  sections into one
- If the dataset is very small (< 20 files), the narrative should acknowledge the
  limited sample size and frame findings as preliminary
- The number of prompt instructions will vary per user — could be 8 or 20. Don't
  force exactly 17. Let the data determine the count.
- The top 3 actionable items in section 5 must be the 3 that cover the largest
  share of denials, not the 3 that sound most impressive

### Key Rules

1. Every number must come from the real analysis — no fabricated data
2. Every quote must be a real quote from a real file
3. The taxonomy percentages must be calculated from real counts
4. The prompt instructions must trace back to actual denial patterns
5. The copy button on the prompt block must work (include the JS)

After generating, open the file in the user's browser.

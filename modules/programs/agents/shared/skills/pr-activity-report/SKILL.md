---
name: pr-activity-report
description: Quarterly PR Activity Report
allowed-tools: Bash(gh *), Bash(jq *), Bash(mktemp *), Write, Read
---

# pr-activity-report

Arguments: `$ARGUMENTS` (required). Format: `owner/repo` optionally followed by
a quarter like `Q1 2026`. If no quarter given, use the current quarter.

## Quarter date ranges

- Q1: Jan 1 - Mar 31 (start data from the Monday of the week containing Jan 1)
- Q2: Apr 1 - Jun 30
- Q3: Jul 1 - Sep 30
- Q4: Oct 1 - Dec 31

## Step 1: Collect data via `gh` CLI

You need three datasets. Exclude bot authors (login containing `[bot]` or
`dependabot` or `renovate` or `github-actions`). Only count **merged** PRs.

### Dataset 1: Weekly authored/reviewed counts

For every human contributor with repo access, compute per-ISO-week:

- `prs_authored`: number of PRs they authored that were merged that week
- `prs_reviewed`: number of unique PRs they submitted a review on that week

Use `gh api` with GraphQL or REST pagination. Group by ISO week (Monday start).
Include weeks with zero activity so the heatmap has no gaps.

Collect all users who either authored or reviewed at least one PR in the period,
plus anyone with push access who had zero activity (to show gaps).

The output shape is:

```json
[
  { "week_start": "2026-01-05", "user": "alice", "prs_authored": 3, "prs_reviewed": 5 },
  ...
]
```

### Dataset 2: Review pairs

For every (reviewer, author) pair where the reviewer submitted at least one
review on the author's merged PRs during the quarter:

```json
[
  { "reviewer": "alice", "author": "bob", "count": 12 },
  ...
]
```

### Dataset 3: Per-PR detail

For every merged PR in the quarter, collect size and classification data:

```json
[
  {
    "number": 42,
    "user": "alice",
    "title": "feat(auth): add SSO login",
    "merged_at": "2026-01-15T10:00:00Z",
    "additions": 340,
    "deletions": 12,
    "changed_files": 8,
    "size_tier": "L",
    "pr_type": "feat",
    "top_dirs": ["src/auth", "tests/auth"]
  },
  ...
]
```

**Size tiers** (based on additions + deletions):

| Tier | Lines changed |
|------|--------------|
| XS   | 0-9          |
| S    | 10-49        |
| M    | 50-249       |
| L    | 250-999      |
| XL   | 1000+        |

**PR type** parsed from the PR title using this regex:
`^(feat|fix|refactor|chore|docs|test|ci|build|perf)(\(.+?\))?[!]?:`. Falls back
to `"other"` when the title does not match.

**Top directories** derived from the file paths (first two path segments,
deduped, max 5).

### Data collection approach

Use `gh api` with pagination. Suggested approach:

```bash
# Get all merged PRs in date range, including size fields
gh api --paginate "repos/{owner}/{repo}/pulls?state=closed&sort=updated&direction=desc&per_page=100" \
  --jq '.[] | select(.merged_at != null) | select(.merged_at >= "START" and .merged_at < "END") | {number, user: .user.login, title: .title, merged_at: .merged_at, additions, deletions, changed_files}'

# For each PR, get reviews
gh api "repos/{owner}/{repo}/pulls/{number}/reviews" \
  --jq '[.[] | .user.login] | unique'

# For each PR, get file paths (batch alongside reviews)
gh api "repos/{owner}/{repo}/pulls/{number}/files" \
  --jq '[.[] | .filename]'
```

From the file paths, derive `top_dirs` by extracting the first two path segments
of each file (e.g. `src/auth/login.ts` -> `src/auth`), deduping, and keeping the
top 5 by frequency.

Compute `size_tier` from `additions + deletions` using the tier table above.

Parse `pr_type` from `title` using the regex above.

This will be slow for large repos. To speed up, batch requests and cache
results. If there are more than ~500 PRs, process in chunks and show progress.

If the API calls are going to be very numerous (>200 PRs), write a small bash
script that collects everything into a JSON file first, then process it.

## Step 2: Compute summary stats

From the collected data, compute:

1. **Total human PRs merged** in the quarter
2. **Active contributors**: count of people with >= 1 authored or reviewed PR
3. **Top author share**: what % of total PRs the #1 author accounts for, and
   their count
4. **Review coverage**: how many people handle 50%+ of all reviews (sort by
   review count desc, cumulative sum until > 50% of total reviews)
5. **Median PR size**: median of (additions + deletions) across all PRs, with
   its size tier label (e.g. "142 lines (M)")
6. **Code volume**: total additions and deletions for the quarter, formatted as
   `+N / -N` (use `k` suffix for thousands, e.g. `+2.1k / -0.4k`)

Display all six stats as cards in a 3x2 grid.

## Step 3: Write insights

Analyze the data and write opinionated, specific insights. Reference actual
numbers and usernames. Cover:

### Key Takeaways (top-level)

3-5 bullet points covering the most important patterns:

- Authorship concentration (is one person doing disproportionate work?)
- Review load distribution (top-heavy? evenly spread?)
- Author/review imbalances (people who author a lot but rarely review, or vice
  versa)
- Size distribution skew (are most PRs XS/S suggesting good decomposition, or
  lots of XL suggesting review bottleneck risk?)
- Codebase hotspots (top 3-5 directories by PR count, are changes concentrated
  or spread?)
- Any notable patterns (spikes, gaps, siloed clusters)

### Per-section insights

Write a short insight box before each of the three heatmaps, the chord diagram,
the size distribution chart, and the contributor profiles section:

- **Authored PRs**: outlier weeks, consistent vs intermittent contributors
- **Review Activity**: who leads, broadly distributed vs narrow reviewers,
  people with few reviews
- **Author/Review Balance**: healthy ratios, persistent imbalances, caveats
- **Review Network**: bus factor, reciprocity, siloed clusters, recommendations
- **Size Distribution**: who ships large PRs vs small ones, team-wide size
  habits, outliers
- **Contributor Profiles**: notable specialization patterns, who touches the
  broadest vs narrowest parts of the codebase

Be direct. Use color-coded markers: `.good` (green), `.flag` (yellow),
`.concern` (red).

Add a context disclaimer noting this data covers only this repo and contributors
may be active elsewhere.

## Step 4: Generate HTML

Generate a single self-contained `index.html` file in a temp directory
(`mktemp -d`). Use Plotly 2.35.2 and D3 v7. Dark GitHub theme.

The HTML must include, in this order:

1. Title: `{Quarter} {Year} -- PR Activity (Humans Only)` with subtitle
2. Summary stat cards in a 3x2 grid (6 cards total)
3. Context disclaimer insight box
4. Key takeaways insight box
5. Filter buttons (Active contributors >= 3, All with any activity, Everyone)
6. For each of the three heatmaps (Authored, Reviewed, Ratio):
   - Insight box with analysis
   - Panel with Plotly heatmap
7. Size Distribution section (stacked bar chart)
8. PR Type Breakdown section (conditional, stacked bar chart)
9. Chord diagram section:
   - Insight box with review network analysis
   - Threshold filter buttons (>= 5, >= 3, All)
   - D3 chord diagram in SVG with viewBox scaling
10. Contributor profile modal (hidden, shown on click)

Embed the three JSON datasets directly in `<script>` tags.

### Heatmap details

- **Authored & Reviewed**: Red-green activity scale using 90th percentile for
  zmax. Numbers displayed in cells. Sorted by total reviews descending.
- **Ratio**: Green (net reviewer) -> gray (balanced at 1:1) -> red (mostly
  authoring). Scale 0-5, infinity symbol for authored-with-zero-reviews. Show
  colorbar.
- Y-axis labels: `username  (A:NNN R:NNN  +Nk -Nk)` with monospace font,
  padded. The `+Nk -Nk` shows total additions/deletions for that contributor,
  using `k` suffix for thousands (e.g. `+2.1k -0.4k`). For values under 1000,
  show the raw number (e.g. `+340 -12`).
- All heatmaps: 32px cell height, 2px gap, dark background, no mode bar

### Size Distribution chart (new)

Horizontal stacked bar chart (Plotly) showing each contributor's PR count broken
down by size tier. One bar per contributor (same Y-axis order as heatmaps).

Colors for size tiers:
- XS: `#7d8590` (gray)
- S: `#58a6ff` (blue)
- M: `#3fb950` (green)
- L: `#d29922` (orange)
- XL: `#f85149` (red)

Same filter buttons apply. Place after the three heatmaps, before the chord
diagram.

### PR Type Breakdown chart (conditional, new)

Only shown when >= 50% of PRs in the quarter have a parseable conventional
commit prefix in the title (matching the regex from Dataset 3).

When shown: horizontal stacked bar per contributor with colors per type. Use
a distinct color palette (not the size tier colors). Same filter buttons apply.

When omitted: add a brief note in the takeaways explaining that PR type
breakdown was skipped because fewer than 50% of PR titles follow conventional
commit format, and include the actual parse rate percentage.

### Chord diagram details

- Colors from a 25-color palette
- Sorted by total involvement (reviews given + received)
- Hover on arc: show who they review for and who reviews them
- Hover on ribbon: show bidirectional review counts
- Tooltip with fixed positioning, dark background
- viewBox-based SVG so it scales responsively

### Contributor Profile modal (new)

Clicking any username in any Y-axis label, chart label, or stacked bar opens a
modal with:

- **Header**: username, GitHub avatar (from
  `https://github.com/{username}.png?size=64`), total authored and reviewed
  counts
- **Top PRs by size**: top 5 PRs by lines changed (additions + deletions), each
  showing title (linked to the PR on GitHub), size tier badge with tier color,
  `+N -N`, and merge date
- **Size tier distribution**: small donut chart (D3, already loaded) showing
  their personal size tier breakdown
- **Codebase areas**: horizontal bar chart of top 5 directories they touched
  (by PR count), using the `top_dirs` from Dataset 3

Implementation: pure CSS modal toggled by JS. Fixed overlay with `--panel`
background card, max-width 600px, scrollable content. Close on overlay click or
Escape key. No new libraries.

### CSS theme

```
--bg: #0d1117; --fg: #e6edf3; --muted: #7d8590;
--panel: #161b22; --border: #30363d; --accent: #58a6ff;
```

Size tier color variables (for reuse in charts and badges):

```
--tier-xs: #7d8590; --tier-s: #58a6ff; --tier-m: #3fb950;
--tier-l: #d29922; --tier-xl: #f85149;
```

## Step 5: Output

Print the path to the generated `index.html` file. The user can then deploy it
however they choose (e.g. `surge`, `gh-pages`, local preview).

## Important notes

- If the repo has fewer than 10 PRs in the quarter, mention that in the summary
  and skip the chord diagram.
- Handle GitHub API rate limits gracefully. If you hit limits, use conditional
  requests or wait.
- The entire output is a single HTML file with no external dependencies beyond
  the two CDN scripts.
- Do NOT anonymize usernames. Use actual GitHub logins.
- Sort everything consistently: by total reviews descending, then authored
  descending, then alphabetical.

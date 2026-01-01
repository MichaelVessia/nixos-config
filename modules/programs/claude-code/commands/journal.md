---
allowed-tools: AskUserQuestion, Bash
description: End-of-day 5-minute checkin (Physical, Mind, Craft, Presence)
model: claude-haiku-4-5
---

Run a quick end-of-day checkin using the AskUserQuestion tool, then log to Obsidian.

## Step 1: Ask Questions

Use AskUserQuestion to ask ALL 4 questions at once:

1. **Physical** - How was your body today?
   - Options: Hard (pushed yourself), Easy (comfortable), Rest (recovery day)

2. **Mind** - How was your mental state?
   - Options: Clear (focused, calm), Cluttered (scattered, noisy)

3. **Craft** - How was your work quality?
   - Options: Leverage (high-impact work), Noise (busy but not impactful)

4. **Presence** - How present were you?
   - Options: Present (engaged, aware), Distracted (pulled away, unfocused)

Frame it as: "No judgment. Just data."

## Step 2: Log Entry

After receiving answers, append to `~/notes/YYYY-MM-DD.md`:

```markdown
## HH:MM - Daily Checkin

#daily-checkin

| Pillar | State |
|--------|-------|
| Physical | [answer] |
| Mind | [answer] |
| Craft | [answer] |
| Presence | [answer] |
```

If user selected "Other" and provided custom text for any pillar, include that text.

Create the file with `# Journal YYYY-MM-DD` header if it doesn't exist.

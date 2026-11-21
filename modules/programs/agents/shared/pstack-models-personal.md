# pstack model configuration (T3, personal hosts). One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat's model (`delegate_task` omits `target`). Alias entries in a panel list still count toward its fan-out.
# budget: mixed (high for decisions, medium for features and swarm)
feature, refactoring: antigravity/gemini-4-neon thought_level=medium
bug-fix: antigravity/gemini-4-neon thought_level=high
perf-issue: antigravity/gemini-4-neon thought_level=high
hillclimb: antigravity/gemini-4-neon thought_level=high
judgment and prose: antigravity/gemini-4-neon thought_level=high
arena runners: antigravity/gemini-4-neon thought_level=high, grok/grok-4.7 reasoningEffort=high
arena cross-judge pool: antigravity/gemini-4-neon thought_level=high, grok/grok-4.7 reasoningEffort=high
swarm workers: grok/grok-4.7 reasoningEffort=medium
interrogate reviewers: antigravity/gemini-4-neon thought_level=high, grok/grok-4.7 reasoningEffort=high
session hook: on

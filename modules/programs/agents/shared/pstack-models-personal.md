# pstack model configuration (T3, personal hosts). One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat's model (`delegate_task` omits `target`). Alias entries in a panel list still count toward its fan-out.
# budget: mixed (high for decisions, medium for features and swarm)
# Chat stays on Antigravity gemini-4-neon. These roles are workers.
feature, refactoring: codex/gpt-6.2-sol reasoningEffort=medium
bug-fix: codex/gpt-6.2-sol reasoningEffort=high
perf-issue: grok/grok-4.7 reasoningEffort=high
hillclimb: grok/grok-4.7 reasoningEffort=high
judgment and prose: codex/gpt-6.2-sol reasoningEffort=high
arena runners: codex/gpt-6.2-sol reasoningEffort=high, grok/grok-4.7 reasoningEffort=high
arena cross-judge pool: codex/gpt-6.2-sol reasoningEffort=high, grok/grok-4.7 reasoningEffort=high
swarm workers: grok/grok-4.7 reasoningEffort=medium
interrogate reviewers: codex/gpt-6.2-sol reasoningEffort=high, grok/grok-4.7 reasoningEffort=high
session hook: on

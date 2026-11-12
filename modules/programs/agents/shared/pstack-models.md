# pstack model configuration (T3). One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat's model (`delegate_task` omits `target`). Alias entries in a panel list still count toward its fan-out.
# budget: medium (high)
feature, refactoring: claudeAgent/claude-opus-5-5 effort=high
bug-fix: claudeAgent/claude-opus-5-5 effort=high
perf-issue: codex/gpt-6.1-sol reasoningEffort=high
hillclimb: codex/gpt-6.1-sol reasoningEffort=high
judgment and prose: claudeAgent/claude-opus-5-5 effort=high
hardest tasks: claudeAgent/claude-opus-5-5 effort=high
how explorer: codex/gpt-6.1-terra reasoningEffort=high
how explainer: claudeAgent/claude-opus-5-5 effort=high
why investigators: codex/gpt-6.1-terra reasoningEffort=high
why synthesizer: claudeAgent/claude-opus-5-5 effort=high
reflect tooling: codex/gpt-6.1-sol reasoningEffort=high
reflect judgment, divergent, synthesizer: claudeAgent/claude-opus-5-5 effort=high
arena runners: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.1-sol reasoningEffort=high
arena cross-judge pool: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.1-sol reasoningEffort=high
swarm workers: codex/gpt-6.1-sol reasoningEffort=high
architect runners: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.1-sol reasoningEffort=high
interrogate reviewers: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.1-sol reasoningEffort=high
session hook: on

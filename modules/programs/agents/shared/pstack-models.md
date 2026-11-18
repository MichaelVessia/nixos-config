# pstack model configuration (T3). One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat's model (`delegate_task` omits `target`). Alias entries in a panel list still count toward its fan-out.
# budget: mixed (high for decisions, medium for features, exploration, tooling, swarm)
feature, refactoring: claudeAgent/claude-opus-5-5 effort=medium
bug-fix: claudeAgent/claude-opus-5-5 effort=high
perf-issue: claudeAgent/claude-fable-5-2 effort=high
hillclimb: claudeAgent/claude-fable-5-2 effort=high
judgment and prose: claudeAgent/claude-opus-5-5 effort=high
hardest tasks: claudeAgent/claude-fable-5-2 effort=high
how explorer: codex/gpt-6.1-terra reasoningEffort=medium
how explainer: claudeAgent/claude-opus-5-5 effort=medium
why investigators: codex/gpt-6.1-terra reasoningEffort=medium
why synthesizer: claudeAgent/claude-opus-5-5 effort=high
reflect tooling: codex/gpt-6.2-sol reasoningEffort=medium
reflect judgment, divergent, synthesizer: claudeAgent/claude-opus-5-5 effort=high
arena runners: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.2-sol reasoningEffort=high
arena cross-judge pool: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.2-sol reasoningEffort=high
swarm workers: codex/gpt-6.2-sol reasoningEffort=medium
architect runners: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.2-sol reasoningEffort=high
interrogate reviewers: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.2-sol reasoningEffort=high
session hook: on

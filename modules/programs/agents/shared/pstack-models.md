# pstack model configuration (T3). One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat's model (`delegate_task` omits `target`). Alias entries in a panel list still count toward its fan-out.
# budget: medium (high)
feature, refactoring: claudeAgent/claude-opus-5-5 effort=high
bug-fix: claudeAgent/claude-opus-5-5 effort=high
perf-issue: cursor/grok-4.7 reasoning_effort=high
hillclimb: cursor/grok-4.7 reasoning_effort=high
judgment and prose: claudeAgent/claude-opus-5-5 effort=high
hardest tasks: claudeAgent/claude-opus-5-5 effort=high
how explorer: cursor/grok-4.7 reasoning_effort=high
how explainer: claudeAgent/claude-opus-5-5 effort=high
why investigators: cursor/grok-4.7 reasoning_effort=high
why synthesizer: claudeAgent/claude-opus-5-5 effort=high
reflect tooling: cursor/grok-4.7 reasoning_effort=high
reflect judgment, divergent, synthesizer: claudeAgent/claude-opus-5-5 effort=high
arena runners: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.1-sol reasoningEffort=high, cursor/gemini-4-carbon reasoning_effort=high
arena cross-judge pool: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.1-sol reasoningEffort=high, cursor/gemini-4-carbon reasoning_effort=high
swarm workers: cursor/grok-4.7 reasoning_effort=high
architect runners: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.1-sol reasoningEffort=high, cursor/gemini-4-carbon reasoning_effort=high
interrogate reviewers: claudeAgent/claude-opus-5-5 effort=high, codex/gpt-6.1-sol reasoningEffort=high, cursor/gemini-4-carbon reasoning_effort=high
session hook: on

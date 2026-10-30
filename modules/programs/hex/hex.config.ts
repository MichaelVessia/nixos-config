import { defineHexConfig, openApplication, press, typeText } from "@hex/commands"
import type { CommandDefinition, CommandMetadata, NativeAction, PressOptions } from "@hex/commands"
import { cleanSpeech, slackStyle } from "./transformations.ts"

function t3Command(
  phrases: CommandMetadata["phrases"],
  description: string,
  run: () => readonly NativeAction[],
): CommandDefinition {
  const [first, ...rest] = phrases
  return {
    phrases: [first, ...rest, ...phrases.map((phrase) => phrase.replace(/^t3 /, "t three "))],
    group: "T3 Code",
    description,
    when: { application: "T3 Code (Nightly)" },
    run,
  }
}

function t3Shortcut(
  phrases: CommandMetadata["phrases"],
  description: string,
  shortcut: PressOptions,
): CommandDefinition {
  return t3Command(phrases, description, () => [press("escape"), press(shortcut)])
}

function t3Picker(shortcut: PressOptions, query: string): readonly NativeAction[] {
  return [
    press("escape"),
    press(shortcut),
    press({ key: "a", modifiers: ["command"] }),
    typeText(query),
    press("enter"),
  ]
}

function t3Project(phrases: CommandMetadata["phrases"], project: string): CommandDefinition {
  return t3Command(phrases, `Start a new thread draft in ${project}`, () =>
    t3Picker({ key: "n", modifiers: ["command"] }, project))
}

export default defineHexConfig({
  transformations: {
    "clean-speech": {
      name: "Clean speech",
      description: "Remove um, uh, erm, and repeated I, I'll, and, or but",
      transform: cleanSpeech,
    },
    "slack-style": {
      name: "Slack style",
      description: "Lowercase prose and omit its final period; keep questions, code, and URLs",
      transform: slackStyle,
    },
  },
  commands: {
    "t3-new-thread": t3Shortcut(
      ["t3 new thread"],
      "Start a new thread draft in the current project",
      { key: "n", modifiers: ["command", "shift"] },
    ),
    "t3-use-opus": t3Command(
      ["t3 use opus"],
      "Select Opus 5.5",
      () => t3Picker({ key: "m", modifiers: ["command", "shift"] }, "Opus 5.5"),
    ),
    "t3-use-sol": t3Command(
      ["t3 use sol", "t3 use soul", "t3 use seoul"],
      "Select GPT 6.1 Sol through Codex",
      () => t3Picker({ key: "m", modifiers: ["command", "shift"] }, "codex 6.1 sol"),
    ),
    "t3-next-thread": t3Shortcut(
      ["t3 next thread"],
      "Go to the next thread",
      { key: "j", modifiers: ["option"] },
    ),
    "t3-previous-thread": t3Shortcut(
      ["t3 previous thread"],
      "Go to the previous thread",
      { key: "k", modifiers: ["option"] },
    ),
    "t3-effort": t3Shortcut(
      ["t3 effort"],
      "Open the reasoning effort selector",
      { key: "e", modifiers: ["command", "shift"] },
    ),
    "t3-show-changes": t3Shortcut(
      ["t3 show changes"],
      "Toggle the diff panel",
      { key: "d", modifiers: ["command"] },
    ),
    "t3-floai": t3Project(
      ["t3 new thread in flow ai", "t3 work on flow ai", "t3 work on floai"],
      "floai",
    ),
    "t3-web-monorepo": t3Project(
      ["t3 new thread in web", "t3 work on web", "t3 work on web monorepo"],
      "web-monorepo",
    ),
    "t3-flobot": t3Project(
      ["t3 new thread in flow bot", "t3 work on flow bot", "t3 work on flobot"],
      "flobot",
    ),
    "t3-flo360": t3Project(
      [
        "t3 new thread in flow 360", "t3 new thread in flow three sixty",
        "t3 work on flow 360", "t3 work on flow three sixty", "t3 work on flo360",
      ],
      "flo360",
    ),
    "t3-nixos-config": t3Project(
      ["t3 new thread in nix config", "t3 work on nix config", "t3 work on nixos config", "t3 work on nix os config"],
      "nixos-config",
    ),
    "open-t3-code": {
      phrases: ["open t3 code", "open t three code"],
      group: "Applications",
      description: "Open T3 Code Nightly",
      action: openApplication("/Applications/T3 Code (Nightly).app"),
    },
    "open-ghostty": {
      phrases: ["open ghostty", "open ghostie", "open ghosty", "open terminal"],
      group: "Applications",
      description: "Open Ghostty",
      action: openApplication("Ghostty"),
    },
    "open-slack": {
      phrases: ["open slack"],
      group: "Applications",
      description: "Open Slack",
      action: openApplication("Slack"),
    },
  },
})

import { defineHexConfig, openApplication } from "@hex/commands"
import { cleanSpeech, slackStyle } from "./transformations.ts"

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

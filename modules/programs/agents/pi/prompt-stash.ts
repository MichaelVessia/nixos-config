import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function promptStash(pi: ExtensionAPI) {
  let stashedPrompt: string | undefined;

  pi.registerShortcut("ctrl+s", {
    description: "Stash or restore the current prompt",
    handler: (ctx) => {
      const currentPrompt = ctx.ui.getEditorText();

      if (currentPrompt.length > 0) {
        stashedPrompt = currentPrompt;
        ctx.ui.setEditorText("");
        ctx.ui.notify(
          "Prompt stashed. Send another prompt or press Ctrl+S to restore it.",
          "info",
        );
        return;
      }

      if (stashedPrompt === undefined) {
        ctx.ui.notify("No prompt is stashed.", "info");
        return;
      }

      ctx.ui.setEditorText(stashedPrompt);
      stashedPrompt = undefined;
      ctx.ui.notify("Prompt restored.", "info");
    },
  });

  pi.on("input", (event, ctx) => {
    if (event.source !== "interactive" || stashedPrompt === undefined) {
      return;
    }

    ctx.ui.setEditorText(stashedPrompt);
    stashedPrompt = undefined;
  });
}

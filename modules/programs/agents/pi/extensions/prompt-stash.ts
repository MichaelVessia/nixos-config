import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

export default function promptStash(pi: ExtensionAPI): void {
  let stashedPrompt: string | undefined;

  const restorePrompt = (ctx: ExtensionContext): void => {
    if (stashedPrompt === undefined) return;

    ctx.ui.setEditorText(stashedPrompt);
    stashedPrompt = undefined;
    ctx.ui.notify("Prompt restored.", "info");
  };

  pi.registerShortcut("ctrl+s", {
    description: "Stash or restore the current prompt",
    handler: async (ctx) => {
      const currentPrompt = ctx.ui.getEditorText();

      if (currentPrompt.length > 0) {
        stashedPrompt = currentPrompt;
        ctx.ui.setEditorText("");
        ctx.ui.notify("Prompt stashed. Send another prompt or press Ctrl+S to restore it.", "info");
        return;
      }

      if (stashedPrompt === undefined) {
        ctx.ui.notify("No prompt is stashed.", "info");
        return;
      }

      restorePrompt(ctx);
    },
  });

  pi.on("input", (event, ctx) => {
    if (event.source === "interactive") restorePrompt(ctx);
  });
}

import {
  CustomEditor,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { matchesKey } from "@earendil-works/pi-tui";
import { Effect, Option, Ref } from "effect";

class PromptStashEditor extends CustomEditor {
  onPromptStash: (() => void) | undefined;

  override handleInput(data: string): void {
    if (matchesKey(data, "ctrl+s")) {
      this.onPromptStash?.();
      return;
    }

    super.handleInput(data);
  }
}

/** Register Claude Code-style prompt stashing for Pi. */
export default function promptStash(pi: ExtensionAPI): void {
  const stash = Effect.runSync(Ref.make(Option.none<string>()));

  const restorePrompt = (ctx: ExtensionContext) =>
    Effect.gen(function* () {
      const prompt = yield* Ref.getAndSet(stash, Option.none());
      if (Option.isNone(prompt)) return false;

      yield* Effect.sync(() => {
        ctx.ui.setEditorText(prompt.value);
        ctx.ui.notify("Prompt restored.", "info");
      });

      return true;
    });

  const toggleStash = (ctx: ExtensionContext) =>
    Effect.gen(function* () {
      const currentPrompt = yield* Effect.sync(() => ctx.ui.getEditorText());

      if (currentPrompt.length > 0) {
        yield* Ref.set(stash, Option.some(currentPrompt));
        yield* Effect.sync(() => {
          ctx.ui.setEditorText("");
          ctx.ui.notify(
            "Prompt stashed. Send another prompt or press Ctrl+S to restore it.",
            "info",
          );
        });
        return;
      }

      const restored = yield* restorePrompt(ctx);
      if (!restored) {
        yield* Effect.sync(() => {
          ctx.ui.notify("No prompt is stashed.", "info");
        });
      }
    });

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setEditorComponent((tui, theme, keybindings) => {
      const editor = new PromptStashEditor(tui, theme, keybindings);
      editor.onPromptStash = () => Effect.runSync(toggleStash(ctx));
      return editor;
    });
  });

  pi.on("input", (event, ctx) => {
    if (event.source !== "interactive") return;
    return Effect.runPromise(Effect.asVoid(restorePrompt(ctx)));
  });
}

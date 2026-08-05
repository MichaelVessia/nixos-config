import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Effect, Option, Ref } from "effect";

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

  pi.registerShortcut("ctrl+s", {
    description: "Stash or restore the current prompt",
    handler: (ctx) => Effect.runPromise(toggleStash(ctx)),
  });

  pi.on("input", (event, ctx) => {
    if (event.source !== "interactive") return;
    return Effect.runPromise(Effect.asVoid(restorePrompt(ctx)));
  });
}

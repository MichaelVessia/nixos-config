import {
  getAgentDir,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import * as NodeFileSystem from "@effect/platform-node/NodeFileSystem";
import * as NodePath from "@effect/platform-node/NodePath";
import { Effect, FileSystem, Layer, Path, Ref } from "effect";

const CONFIG_FIELD = "pi-gpt-fast-mode";
const SEGMENT_ID = "fast-mode";
const SERVICE_TIER = "priority";

const SUPPORTED_MODELS = new Set([
  "openai/gpt-5.4",
  "openai/gpt-5.4-mini",
  "openai/gpt-5.5",
  "openai/gpt-5.6",
  "openai/gpt-5.6-sol",
  "openai/gpt-5.6-terra",
  "openai/gpt-5.6-luna",
  "openai-codex/gpt-5.4",
  "openai-codex/gpt-5.4-mini",
  "openai-codex/gpt-5.5",
  "openai-codex/gpt-5.6",
  "openai-codex/gpt-5.6-sol",
  "openai-codex/gpt-5.6-terra",
  "openai-codex/gpt-5.6-luna",
]);

const isRecord = (value: unknown): value is Readonly<Record<string, unknown>> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const isConfiguredEnabled = (settings: unknown): boolean => {
  if (!isRecord(settings)) return false;

  const config = settings[CONFIG_FIELD];
  return isRecord(config) && config.enabled === true;
};

const modelKey = (ctx: ExtensionContext): string | undefined => {
  if (!ctx.model) return undefined;
  return `${ctx.model.provider}/${ctx.model.id}`;
};

const isSupported = (ctx: ExtensionContext): boolean => {
  const key = modelKey(ctx);
  return key !== undefined && SUPPORTED_MODELS.has(key);
};

const platformLayer = Layer.mergeAll(NodeFileSystem.layer, NodePath.layer);

const loadDefaultEnabled = Effect.gen(function* () {
  const fileSystem = yield* FileSystem.FileSystem;
  const path = yield* Path.Path;
  const settingsText = yield* fileSystem.readFileString(
    path.join(getAgentDir(), "settings.json"),
  );
  const settings: unknown = yield* Effect.try(() => JSON.parse(settingsText));
  return isConfiguredEnabled(settings);
}).pipe(
  Effect.orElseSucceed(() => false),
  Effect.provide(platformLayer),
);

/** Register GPT priority-service-tier controls for Pi. */
export default function gptFastMode(pi: ExtensionAPI): void {
  const enabled = Effect.runSync(Ref.make(false));

  const updatePowerbar = (ctx: ExtensionContext) =>
    Effect.gen(function* () {
      const isEnabled = yield* Ref.get(enabled);
      yield* Effect.sync(() => {
        pi.events.emit("powerbar:update", {
          id: SEGMENT_ID,
          text: isEnabled && isSupported(ctx) ? "FAST" : undefined,
          icon: "⚡",
          color: "warning",
        });
      });
    });

  const toggle = (ctx: ExtensionContext) =>
    Effect.gen(function* () {
      const isEnabled = yield* Ref.modify(enabled, (current) => [
        !current,
        !current,
      ]);
      yield* updatePowerbar(ctx);

      yield* Effect.sync(() => {
        if (!isEnabled) {
          ctx.ui.notify("GPT Fast mode disabled.", "info");
        } else if (isSupported(ctx)) {
          ctx.ui.notify(
            `GPT Fast mode enabled (service_tier: ${SERVICE_TIER}).`,
            "info",
          );
        } else {
          ctx.ui.notify(
            `GPT Fast mode enabled, but ${modelKey(ctx) ?? "the current model"} is unsupported.`,
            "warning",
          );
        }
      });
    });

  pi.events.emit("powerbar:register-segment", {
    id: SEGMENT_ID,
    label: "GPT Fast Mode",
  });

  pi.registerCommand("fast", {
    description: "Toggle GPT Fast mode (service_tier: priority)",
    handler: (_args, ctx) => Effect.runPromise(toggle(ctx)),
  });

  pi.registerShortcut("ctrl+alt+m", {
    description: "Toggle GPT Fast mode",
    handler: (ctx) => Effect.runPromise(toggle(ctx)),
  });

  pi.on("session_start", (_event, ctx) =>
    Effect.runPromise(
      Effect.gen(function* () {
        const isEnabled = yield* loadDefaultEnabled;
        yield* Ref.set(enabled, isEnabled);
        yield* updatePowerbar(ctx);
      }),
    ),
  );

  pi.on("model_select", (_event, ctx) => Effect.runPromise(updatePowerbar(ctx)));

  pi.on("before_provider_request", (event, ctx) =>
    Effect.runPromise(
      Effect.gen(function* () {
        const isEnabled = yield* Ref.get(enabled);
        if (!isEnabled || !isSupported(ctx) || !isRecord(event.payload)) {
          return undefined;
        }
        if (event.payload.model !== ctx.model?.id) return undefined;

        return { ...event.payload, service_tier: SERVICE_TIER };
      }),
    ),
  );
}

import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  getAgentDir,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";

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

const modelKey = (ctx: ExtensionContext): string | undefined => {
  if (!ctx.model) return undefined;
  return `${ctx.model.provider}/${ctx.model.id}`;
};

const isSupported = (ctx: ExtensionContext): boolean => {
  const key = modelKey(ctx);
  return key !== undefined && SUPPORTED_MODELS.has(key);
};

const loadDefaultEnabled = (): boolean => {
  try {
    const settings = JSON.parse(
      readFileSync(join(getAgentDir(), "settings.json"), "utf8"),
    ) as Record<string, unknown>;
    const config = settings[CONFIG_FIELD];
    return (
      typeof config === "object" &&
      config !== null &&
      !Array.isArray(config) &&
      (config as { enabled?: unknown }).enabled === true
    );
  } catch {
    return false;
  }
};

export default function gptFastMode(pi: ExtensionAPI): void {
  let enabled = loadDefaultEnabled();

  const updatePowerbar = (ctx: ExtensionContext): void => {
    pi.events.emit("powerbar:update", {
      id: SEGMENT_ID,
      text: enabled && isSupported(ctx) ? "FAST" : undefined,
      icon: "⚡",
      color: "warning",
    });
  };

  const toggle = (ctx: ExtensionContext): void => {
    enabled = !enabled;
    updatePowerbar(ctx);

    if (!enabled) {
      ctx.ui.notify("GPT Fast mode disabled.", "info");
    } else if (isSupported(ctx)) {
      ctx.ui.notify(`GPT Fast mode enabled (service_tier: ${SERVICE_TIER}).`, "info");
    } else {
      ctx.ui.notify(`GPT Fast mode enabled, but ${modelKey(ctx) ?? "the current model"} is unsupported.`, "warning");
    }
  };

  pi.events.emit("powerbar:register-segment", {
    id: SEGMENT_ID,
    label: "GPT Fast Mode",
  });

  pi.registerCommand("fast", {
    description: "Toggle GPT Fast mode (service_tier: priority)",
    handler: async (_args, ctx) => toggle(ctx),
  });

  pi.registerShortcut("ctrl+alt+m", {
    description: "Toggle GPT Fast mode",
    handler: async (ctx) => toggle(ctx),
  });

  pi.on("session_start", (_event, ctx) => {
    enabled = loadDefaultEnabled();
    updatePowerbar(ctx);
  });

  pi.on("model_select", (_event, ctx) => updatePowerbar(ctx));

  pi.on("before_provider_request", (event, ctx) => {
    if (!enabled || !isSupported(ctx)) return undefined;
    if (!event.payload || typeof event.payload !== "object") return undefined;

    const payload = event.payload as Record<string, unknown>;
    if (payload.model !== ctx.model?.id) return undefined;

    return { ...payload, service_tier: SERVICE_TIER };
  });
}

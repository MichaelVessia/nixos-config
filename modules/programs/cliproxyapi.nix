# CLIProxyAPI hub: the Claude and Codex subscription logins live only on this
# host, and every other machine reaches them through the hub endpoint.
#
# The server hashes management.secret-key and rewrites its config on start, so
# the service runs from a writable copy of the sops template.
#
# Tailscale Serve is the only way in. The server binds localhost and the serve
# rule limits it to the tailnet. ExecStartPost reasserts the rule because T3
# also edits this host's serve config.
#
# Log accounts in on this host (the auth files land in ~/.cli-proxy-api):
#   cli-proxy-api -config ~/.local/state/cliproxyapi/config.yaml -claude-login -no-browser
#   cli-proxy-api -config ~/.local/state/cliproxyapi/config.yaml -codex-device-login
{
  config,
  lib,
  pkgs,
  ...
}: let
  version = "8.0.75";
  port = 8317;

  # The no-plugin build is static, so it runs on NixOS without patching.
  cliproxyapi = pkgs.stdenvNoCC.mkDerivation {
    pname = "cliproxyapi";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_linux_amd64_no-plugin.tar.gz";
      hash = "sha256-b4Fr5b46RYkbu2iVS3UUCH5XXLTF9OVT/LHdTCfCUlA=";
    };
    sourceRoot = ".";
    installPhase = ''
      install -Dm755 cli-proxy-api $out/bin/cli-proxy-api
    '';
    meta.mainProgram = "cli-proxy-api";
  };

  stateConfig = "${config.xdg.stateHome}/cliproxyapi/config.yaml";
  authDir = "${config.home.homeDirectory}/.cli-proxy-api";

  # T3's usage view groups accounts by email, so two Claude orgs on one login
  # show as one bar. Each token refresh writes the real email back, so a timer
  # sets these labels again. A path unit on the auth dir hits the start limit,
  # because the hub writes kv.db, locks, and logs there all the time.
  emailLabels = {
    "83484a18-ddf6-4634-ad1e-4eac7f1c91e8" = "michael.vessia@personal.ultra";
  };

  relabel = pkgs.writeShellApplication {
    name = "cliproxyapi-relabel";
    runtimeInputs = [pkgs.jq pkgs.coreutils];
    text = ''
      labels=${lib.escapeShellArg (builtins.toJSON emailLabels)}
      for f in ${authDir}/claude-*.json; do
        [ -e "$f" ] || continue
        want=$(jq -r --argjson l "$labels" '$l[.organization_uuid // ""] // empty' "$f")
        [ -n "$want" ] || continue
        [ "$(jq -r '.email' "$f")" = "$want" ] && continue
        tmp="$f.relabel.tmp"
        install -m600 /dev/null "$tmp"
        jq --arg e "$want" '.email = $e' "$f" > "$tmp"
        mv "$tmp" "$f"
      done
    '';
  };
in {
  home.packages = [cliproxyapi];

  sops.templates."cliproxyapi-config.yaml".content = lib.generators.toYAML {} {
    config-version = 8;
    server = {
      host = "127.0.0.1";
      inherit port;
      trusted-proxies = ["127.0.0.1" "::1"];
    };
    management = {
      allow-remote = true;
      secret-key = config.sops.placeholder.cliproxyapi_management_key;
    };
    access.api-keys = [config.sops.placeholder.cliproxyapi_access_key];
    routing = {
      strategy = "round-robin";
      # Accounts keep separate prompt caches, so a thread stays on one account.
      session-affinity = true;
      session-affinity-ttl = "1h";
      retry = {
        request-retry = 3;
        max-retry-interval = 30;
      };
    };
    oauth.auth-dir = "~/.cli-proxy-api";
  };

  systemd.user.services.cliproxyapi = {
    Unit = {
      Description = "CLIProxyAPI hub";
      After = ["sops-nix.service" "network-online.target"];
      Wants = ["sops-nix.service"];
      # Activation restarts sops-nix after secret changes. This restarts the
      # hub with it, so the working config copy picks up the new keys.
      PartOf = ["sops-nix.service"];
    };
    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/install -Dm600 ${config.sops.templates."cliproxyapi-config.yaml".path} ${stateConfig}";
      ExecStart = "${lib.getExe cliproxyapi} -config ${stateConfig}";
      ExecStartPost = "${lib.getExe pkgs.tailscale} serve --bg --https=${toString port} http://127.0.0.1:${toString port}";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = ["default.target"];
  };

  systemd.user.services.cliproxyapi-relabel = {
    Unit.Description = "Set CLIProxyAPI account email labels";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe relabel;
    };
  };

  systemd.user.timers.cliproxyapi-relabel = {
    Unit.Description = "Set CLIProxyAPI account email labels every minute";
    Timer = {
      OnActiveSec = "0";
      OnUnitActiveSec = "1min";
      AccuracySec = "10s";
    };
    Install.WantedBy = ["timers.target"];
  };
}

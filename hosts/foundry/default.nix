{pkgs, ...}: {
  imports = [./hardware-configuration.nix];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "foundry";
  networking.networkmanager.enable = true;
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.foundry = {
    isNormalUser = true;
    description = "Foundry development user";
    extraGroups = ["wheel" "networkmanager"];
    shell = pkgs.zsh;
    # Keeps T3 Code's systemd user service running without a login session.
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObTdZXSO7j+J+1CKMgpcKvPPhCEZh1c4FT0hNuYTu1r michaelvessia@framework13"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhZQaY3xFx3zMord/MUJhPbHur1sVZDkJLNWz9XIZXU michael.vessia@flosports.tv"
    ];
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [22000];

  services.tailscale = {
    enable = true;
    # Lets T3 Code configure Tailscale Serve without root.
    extraSetFlags = ["--operator=foundry"];
  };

  services.opentelemetry-collector = {
    enable = true;
    package = pkgs.opentelemetry-collector-contrib;
    validateConfigFile = true;
    settings = {
      receivers.host_metrics = {
        collection_interval = "30s";
        scrapers = {
          cpu.metrics."system.cpu.utilization".enabled = true;
          memory.metrics."system.memory.utilization".enabled = true;
          filesystem.metrics."system.filesystem.utilization".enabled = true;
          disk = {};
          load = {};
          network = {};
          paging = {};
          processes = {};
        };
      };
      processors = {
        memory_limiter = {
          check_interval = "1s";
          limit_mib = 192;
          spike_limit_mib = 48;
        };
        resourcedetection = {
          detectors = ["system"];
          timeout = "2s";
          override = false;
          system = {
            hostname_sources = ["os"];
            resource_attributes."host.id".enabled = true;
          };
        };
        resource.attributes = [
          {
            key = "host.name";
            value = "foundry";
            action = "upsert";
          }
          {
            key = "service.name";
            value = "foundry-host";
            action = "upsert";
          }
        ];
        batch = {
          timeout = "10s";
          send_batch_size = 1024;
        };
      };
      # Private LAN ingestion is source-allowlisted on SigNoz CT 124.
      exporters.otlp_grpc = {
        endpoint = "192.168.1.10:4317";
        tls.insecure = true;
      };
      service.pipelines.metrics = {
        receivers = ["host_metrics"];
        processors = ["memory_limiter" "resourcedetection" "resource" "batch"];
        exporters = ["otlp_grpc"];
      };
    };
  };
  # T3 Code's SSH backend runs its downloaded generic-Linux release binary.
  programs.nix-ld.enable = true;

  programs.zsh.enable = true;
  environment.systemPackages = [pkgs.nano];
  # SSH clients such as Ghostty need their terminfo for correct line editing.
  environment.enableAllTerminfo = true;
  systemd.tmpfiles.rules = ["d /home/foundry/.cache/tmp 0700 foundry users -"];

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    accept-flake-config = true;
    trusted-users = ["root" "foundry"];
    extra-substituters = ["https://cache.numtide.com"];
    extra-trusted-public-keys = ["niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="];
  };

  programs.nh = {
    enable = true;
    flake = "/home/foundry/nixos-config";
  };

  system.stateVersion = "26.05";
}

{
  pkgs,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/homelab-ca/nixos.nix
    ../../modules/host-metrics.nix
  ];

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

  users.users.${username} = {
    isNormalUser = true;
    # Keep the UID from the original foundry user so existing files stay owned.
    uid = 1000;
    description = "Foundry development user";
    extraGroups = ["wheel" "networkmanager" "docker"];
    shell = pkgs.zsh;
    # Keeps T3 Code's systemd user service running without a login session.
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObTdZXSO7j+J+1CKMgpcKvPPhCEZh1c4FT0hNuYTu1r michaelvessia@framework13"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhZQaY3xFx3zMord/MUJhPbHur1sVZDkJLNWz9XIZXU michael.vessia@flosports.tv"
    ];
  };

  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [22000];
    # mosh sessions survive foundry stalls and client network changes.
    allowedUDPPortRanges = [
      {
        from = 60000;
        to = 61000;
      }
    ];
  };

  # Open mosh only on the tailnet, not on the LAN.
  programs.mosh = {
    enable = true;
    openFirewall = false;
  };

  services.tailscale = {
    enable = true;
    # Lets T3 Code configure Tailscale Serve without root.
    extraSetFlags = ["--operator=${username}"];
  };

  # Parallel agent checks can exhaust RAM and swap until sshd stops answering.
  # Kill type checkers and linters first; keep SSH, Tailscale, and T3 alive.
  services.earlyoom = {
    enable = true;
    freeSwapThreshold = 20;
    extraArgs = [
      "--prefer"
      "^(tsc|tsgolint|jest-worker)$"
      "--avoid"
      "^(sshd|sshd-session|tailscaled|t3|systemd|systemd-journal|systemd-logind)$"
    ];
  };

  # Project checks, such as flobot's check:runtime, need a Docker daemon.
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29;
  };

  # T3 Code's SSH backend runs its downloaded generic-Linux release binary.
  programs.nix-ld.enable = true;

  programs.zsh.enable = true;
  environment.systemPackages = [pkgs.nano];
  # SSH clients such as Ghostty need their terminfo for correct line editing.
  environment.enableAllTerminfo = true;
  systemd.tmpfiles.rules = [
    "d /home/${username}/.cache/tmp 0700 ${username} users -"
    # T3 worktrees and Git worktree metadata store absolute paths from the old home.
    "L /home/foundry - - - - /home/${username}"
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    accept-flake-config = true;
    trusted-users = ["root" username];
    extra-substituters = ["https://cache.numtide.com"];
    extra-trusted-public-keys = ["niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="];
  };

  programs.nh = {
    enable = true;
    flake = "/home/${username}/nixos-config";
  };

  system.stateVersion = "26.05";
}

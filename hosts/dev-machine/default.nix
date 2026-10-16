# EC2 Dev Machine from flocasts/floai's dev-machine Terraform module. First
# boot switches to this host without GitHub credentials, so it must not use
# private flake inputs. See the module README for the host contract.
{
  modulesPath,
  pkgs,
  username,
  ...
}: {
  imports = ["${modulesPath}/virtualisation/amazon-image.nix"];

  networking.hostName = "dev-machine";
  time.timeZone = "America/New_York";

  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  users.users.${username} = {
    isNormalUser = true;
    description = "Dev Machine user";
    extraGroups = ["wheel" "docker"];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObTdZXSO7j+J+1CKMgpcKvPPhCEZh1c4FT0hNuYTu1r michaelvessia@framework13"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhZQaY3xFx3zMord/MUJhPbHur1sVZDkJLNWz9XIZXU michael.vessia@flosports.tv"
    ];
  };

  # The user has no password, so sudo cannot ask for one.
  security.sudo.wheelNeedsPassword = false;

  # Tailscale is the way in once the module's bootstrap access is off.
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };
  networking.firewall.trustedInterfaces = ["tailscale0"];

  # Project checks, such as flobot's check:runtime, need a Docker daemon.
  virtualisation.docker.enable = true;

  # T3 Code's SSH backend runs its downloaded generic-Linux release binary.
  programs.nix-ld.enable = true;

  # nh - nix helper for better CLI experience
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 3";
    flake = "/home/${username}/nixos-config";
  };

  programs.zsh.enable = true;
  environment.systemPackages = [pkgs.git];
  # SSH clients such as Ghostty need their terminfo for correct line editing.
  environment.enableAllTerminfo = true;
  # shell.nix sets TMPDIR here.
  systemd.tmpfiles.rules = [
    "d /home/${username}/.cache/tmp 0700 ${username} users -"
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    accept-flake-config = true;
    trusted-users = ["root" username];
    extra-substituters = ["https://cache.numtide.com"];
    extra-trusted-public-keys = ["niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="];
  };

  system.stateVersion = "26.05";
}

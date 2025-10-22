{
  config,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;
    userName = "Michael Vessia";
    userEmail = "michael@vessia.net";
    extraConfig = {
      core.editor = "nvim";
    };
  };

  home.packages = with pkgs; [
    gh
  ];
}

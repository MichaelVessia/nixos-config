{
  config,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;
    settings = {
      user.name = "Michael Vessia";
      user.email = "michael@vessia.net";
      core.editor = "nvim";
    };
  };

  home.packages = with pkgs; [
    gh
  ];
}

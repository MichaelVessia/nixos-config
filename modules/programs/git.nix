{
  config,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;
    aliases = {
      d = "difftool";
    };
    settings = {
      user.name = "Michael Vessia";
      user.email = "michael@vessia.net";
      core.editor = "nvim";
      color.ui = true;
      push.default = "current";
      pull.rebase = false;
      diff.tool = "critique";
      difftool.critique.cmd = ''critique difftool "$LOCAL" "$REMOTE"'';
    };
  };

  home.packages = with pkgs; [
    gh
  ];
}

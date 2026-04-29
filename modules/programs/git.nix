{
  config,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;
    settings = {
      alias = {
        d = "diff";
        dl = "log -p --ext-diff";
        ds = "show --ext-diff";
      };
      user.name = "Michael Vessia";
      user.email = "michael@vessia.net";
      core.editor = "nvim";
      color.ui = true;
      push.default = "current";
      pull.rebase = false;
      diff.external = "difft";
      diff.tool = "difftastic";
      difftool.prompt = false;
      pager.difftool = true;
      difftool.difftastic.cmd = ''difft "$MERGED" "$LOCAL" "abcdef1" "100644" "$REMOTE" "abcdef2" "100644"'';
      credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
    };
  };

  home.packages = with pkgs; [
    gh
  ];
}

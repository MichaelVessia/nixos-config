{pkgs-unstable, ...}: {
  programs.git = {
    enable = true;
    settings = {
      alias = {
        d = "difftool";
      };
      user.name = "Michael Vessia";
      user.email = "michael@vessia.net";
      core.editor = "nvim";
      color.ui = true;
      push.default = "current";
      pull.rebase = false;
      diff.tool = "difftastic";
      difftool.prompt = false;
      pager.difftool = true;
      difftool.difftastic.cmd = ''difft "$MERGED" "$LOCAL" "abcdef1" "100644" "$REMOTE" "abcdef2" "100644"'';
      credential."https://github.com".helper = "!${pkgs-unstable.gh}/bin/gh auth git-credential";
    };
  };

  home.packages = [pkgs-unstable.gh];
}

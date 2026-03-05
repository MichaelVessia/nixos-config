{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [inputs.agent-skills-nix.homeManagerModules.default];

  config = {
    programs.agent-skills = {
      enable = true;
      sources =
        {
          personal.path = ./shared/skills;
        }
        // {
          superpowers = {
            path = inputs.superpowers;
            subdir = "skills";
          };
        }
        // lib.optionalAttrs pkgs.stdenv.isDarwin {
          flocasts = {
            path = inputs.flocasts-skills;
            subdir = "skills";
          };
        };
      skills.enableAll = true;
      targets = {
        claude = {
          dest = "$HOME/.agents/skills";
          structure = "symlink-tree";
        };
        codex = {
          enable = true;
          dest = "$HOME/.agents/skills";
          structure = "symlink-tree";
        };
        opencode = {
          enable = true;
          dest = "$HOME/.agents/skills";
          structure = "symlink-tree";
        };
      };
    };

    home.file = {
      ".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
      ".codex/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
      ".config/opencode/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
    };
  };
}

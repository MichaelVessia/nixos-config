{
  config,
  pkgs,
  ...
}: {
  # Symlink ghostty's built-in themes to the config directory
  home.file.".config/ghostty/themes".source = "${pkgs.ghostty}/share/ghostty/themes";

  # Ghostty terminal emulator configuration
  # Using XDG config file management for declarative configuration
  xdg.configFile."ghostty/config".text = ''
    # Font configuration
    font-family = JetBrains Mono
    font-size = 12

    # Theme (dark or light)
    theme = dark:catppuccin-frappe,light:Novel

    # Background opacity (0.0 to 1.0, where 1.0 is fully opaque)
    background-opacity = 1.0

    # Window padding
    window-padding-x = 10
    window-padding-y = 10

    # Cursor style (block, bar, or underline)
    cursor-style = block

    # Enable bold fonts
    bold-is-bright = true

    # Shell integration
    shell-integration = zsh

    # Tab management keybindings with leader key (ctrl+a)
    keybind = ctrl+a>1=goto_tab:1
    keybind = ctrl+a>2=goto_tab:2
    keybind = ctrl+a>3=goto_tab:3
    keybind = ctrl+a>4=goto_tab:4
    keybind = ctrl+a>5=goto_tab:5
    keybind = ctrl+a>6=goto_tab:6
    keybind = ctrl+a>7=goto_tab:7
    keybind = ctrl+a>8=goto_tab:8
    keybind = ctrl+a>9=goto_tab:9
    keybind = ctrl+a>0=last_tab

    # Additional tab shortcuts with leader
    keybind = ctrl+a>c=new_tab
    keybind = ctrl+a>x=close_tab
    keybind = ctrl+a>h=move_tab:-1
    keybind = ctrl+a>l=move_tab:1
    keybind = ctrl+a>p=previous_tab
    keybind = ctrl+a>n=next_tab
    keybind = ctrl+a>t=toggle_tab_overview
    keybind = ctrl+a>-=new_split:down
    keybind = ctrl+a>shift+\=new_split:right

    # Split navigation
    keybind = ctrl+h=goto_split:left
    keybind = ctrl+j=goto_split:down
    keybind = ctrl+k=goto_split:up
    keybind = ctrl+l=goto_split:right
  '';
}

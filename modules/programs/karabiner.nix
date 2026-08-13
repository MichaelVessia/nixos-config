# Karabiner-Elements configuration for macOS
# Manages keyboard remapping to match Linux/Plasma keybinds
{
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.isDarwin {
  # Karabiner config is stored in ~/.config/karabiner/karabiner.json
  # Home-manager manages this file declaratively
  xdg.configFile."karabiner/karabiner.json".text = builtins.toJSON {
    profiles = [
      {
        name = "Default profile";
        selected = true;
        virtual_hid_keyboard = {keyboard_type_v2 = "ansi";};

        # Simple key remapping
        simple_modifications = [
          {
            # fn (globe) → left_control for all devices
            from = {apple_vendor_top_case_key_code = "keyboard_fn";};
            to = [{key_code = "left_control";}];
          }
        ];

        # Per-device settings (Apple Internal Keyboard)
        devices = [
          {
            identifiers = {
              is_keyboard = true;
              product_id = 835;
              vendor_id = 1452;
            };
            simple_modifications = [
              {
                from = {apple_vendor_top_case_key_code = "keyboard_fn";};
                to = [{key_code = "left_control";}];
              }
            ];
          }
          {
            # BenQ ZOWIE Gaming Mouse: opt-in to event modification
            # (Karabiner ignores pointing devices by default)
            identifiers = {
              is_pointing_device = true;
              product_id = 32770;
              vendor_id = 1189;
            };
            ignore = false;
          }
        ];

        complex_modifications = {
          rules = [
            {
              description = "Cmd + Mouse Forward (button5) → Enter";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    pointing_button = "button5";
                    modifiers = {
                      mandatory = ["command"];
                    };
                  };
                  to = [{key_code = "return_or_enter";}];
                }
              ];
            }
          ];
        };
      }
    ];
  };
}

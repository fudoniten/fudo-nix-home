inputs:

{ username, email, home-directory ? null, ... }:

systemCfg:

{ config, lib, pkgs, ... }:

with lib;
let
  # Validate required arguments
  _ = assert assertMsg (username != null && username != "")
    "username is required";
    assert assertMsg (systemCfg ? desktop && systemCfg.desktop ? type)
    "systemCfg.desktop.type is required";
    assert assertMsg (builtins.elem systemCfg.desktop.type [ "x" "wayland" "darwin" "none" ])
    "systemCfg.desktop.type must be one of: x, wayland, darwin, none";
    null;

  inherit (pkgs.stdenv) isLinux;

  isGui = systemCfg.desktop.type != "none";
  isX = systemCfg.desktop.type == "x";

in {
  config = mkIf isGui {
    home = {
      inherit username;

      packages = with pkgs; [
        # Productivity and office
        abiword                # Lightweight word processor

        # Learning
        anki                   # Flashcard application

        # System tools
        gnome-tweaks           # GNOME customization tool

        # Web browsers
        google-chrome          # Google Chrome browser

        # Communication
        mumble                 # Low-latency voice chat

        # Media
        spotify                # Music streaming
        redshift               # Screen color temperature

        # Utilities
        pv                     # Pipe viewer
        xclip                  # X11 clipboard utility

        # Theme packages
        graphite-cursors       # Cursor theme
      ];

      keyboard = {
        layout = "us";
        options = "";
      };

      file = {
        ".xprofile" = mkIf isX {
          executable = true;
          source = pkgs.writeShellScript "${username}-xsession" ''
            gdmauth=$XAUTHORITY
            unset  XAUTHORITY
            export XAUTHORITY
            xauth merge "$gdmauth"

            if [ -f $HOME/.xinitrc ]; then
              bash --login -i $HOME/.xinitrc
            fi

            export XMODIFIERS="@im=fcitx5"
            export XMODIFIER="@im=fcitx5"
            export GTK_IM_MODULE="fcitx5"
            export QT_IM_MODULE="fcitx5"
          '';
        };
      };
    };

    # Chinese input method configuration
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [
        qt6Packages.fcitx5-chinese-addons
        fcitx5-gtk
        fcitx5-rime
      ];
    };

    programs.firefox.enable = true;

    services.gnome-keyring.enable = true;

    stylix = mkIf (isLinux && isGui) {
      cursor = mkForce {
        package = pkgs.graphite-cursors;
        name = "graphite-dark";
        size = 16;
      };

      opacity = {
        applications = 1.0;
        desktop = 1.0;
        popups = 1.0;
        terminal = 0.9;
      };

      fonts = with pkgs; {
        serif = mkDefault {
          package = liberation_ttf;
          name = "Liberation Serif";
        };
        sansSerif = mkDefault {
          package = nerdfonts;
          name = "Adwaita Sans";
        };
        monospace = mkDefault {
          package = nerdfonts;
          name = "Iosevka Nerd Font";
        };
        emoji = mkDefault {
          package = noto-fonts-emoji;
          name = "Noto Color Emoji";
        };
      };
    };
  };
}

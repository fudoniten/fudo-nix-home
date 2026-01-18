inputs:

{ username, email, home-directory ? null, ... }@userOpts:

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

in {
  config = mkIf isGui {
    home = {
      inherit username;

      packages = with pkgs; [
        # Learning
        anki                   # Flashcard application

        # System tools
        gnome-tweaks           # GNOME customization tool

        # Web browsers
        google-chrome          # Google Chrome browser

        # Communication
        mumble                 # Low-latency voice chat

        # Development
        python3                # Python runtime
        pv                     # Pipe viewer
        racket                 # Racket programming language

        # Media
        spotify                # Music streaming
        xclip                  # X11 clipboard utility

        # Video editors
        kdePackages.kdenlive   # Professional video editor
        openshot-qt            # Simple video editor
        shotcut                # Cross-platform video editor
      ];

      keyboard = {
        layout = "us";
        options = "";
      };
    };

    programs = {
      firefox.enable = true;
      obs-studio.enable = true;
    };

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
          package = oxanium;
          name = "Oxanium";
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

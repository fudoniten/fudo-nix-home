_:

{ username, email, ... }:

systemCfg:

{ config, lib, pkgs, ... }:

with lib;
if (systemCfg.desktop.type == "none") then
  { }
else
  let
    inherit (pkgs.stdenv) isLinux;

    isGui = systemCfg.desktop.type != "none";

  in {
    config = {
      home = {
        inherit username;

        packages = with pkgs; [
          anki # flashcards
          gnome-tweaks
          google-chrome
          mumble
          python3
          pv
          racket
          spotify
          xclip

          # Video editors
          libsForQt5.kdenlive
          openshot-qt
          shotcut
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
            # package = nerdfonts;
            # name = "SourceSans3VF";
            package = oxanium;
            name = "Oxanium";
          };
          monospace = mkDefault {
            package = nerdfonts;
            name = "Iosevka Nerd Font";
            # name = "Hurmit Nerd Font Mono";
          };
          emoji = mkDefault {
            package = noto-fonts-emoji;
            name = "Noto Color Emoji";
          };
        };
      };
    };
  }

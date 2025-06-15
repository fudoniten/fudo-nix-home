inputs:

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
          abiword
          anki # flashcards
          gnome-tweaks
          google-chrome
          mumble
          pv
          redshift
          spotify
          xclip

          # Make sure to add themes here
          graphite-cursors
        ];

        keyboard = {
          layout = "us";
          options = "";
        };

        file = {
          ".xprofile" = mkIf (systemCfg.desktop.type == "x") {
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

      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5.addons = with pkgs; [
          fcitx5-chinese-addons
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

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

  isGui = systemCfg.desktop.type != "none";
  isX = systemCfg.desktop.type == "x";

in {
  config = mkIf isGui {
    home = {
      inherit username;

      packages = with pkgs; [
        abiword
        anki # flashcards
        gnome.gnome-tweaks
        google-chrome
        mumble
        pv
        redshift
        spotify
        xclip
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

    i18n.inputMethod = {
      enabled = "fcitx5";
      fcitx5.addons = with pkgs; [
        fcitx5-chinese-addons
        fcitx5-gtk
        fcitx5-rime
      ];
    };

    programs.firefox.enable = true;

    services.gnome-keyring.enable = true;
  };
}

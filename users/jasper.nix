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

in {
  config = mkIf isGui {
    home = {
      inherit username;

      packages = with pkgs; [
        anki # flashcards
        gnome.gnome-tweaks
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
  };
}

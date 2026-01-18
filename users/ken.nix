inputs:

{ username, home-directory ? null, ... }:

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
        # Productivity and office
        abiword                # Lightweight word processor

        # System tools
        gnome-tweaks           # GNOME customization tool

        # Web browsers
        google-chrome          # Google Chrome browser

        # Graphics and media
        imagemagick            # Image manipulation tools
        redshift               # Screen color temperature adjuster

        # Media
        spotify                # Music streaming
      ];

      keyboard = {
        layout = "us";
        options = "";
      };
    };

    programs.firefox.enable = true;

    services.gnome-keyring.enable = true;
  };
}

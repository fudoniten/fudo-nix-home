inputs:

{ username, email ? null, home-directory ? null, ... }@userOpts:

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
        abiword
        gnome.gnome-tweaks
        google-chrome
        imagemagick
        redshift
        spotify
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

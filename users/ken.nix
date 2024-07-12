inputs:

{ username, ... }:

systemCfg:

{ config, lib, pkgs, ... }:

with lib;
mkIf (systemCfg.desktop.type == "none") {
  config = {
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

inputs:

{ username, ... }:

systemCfg:

{ config, lib, pkgs, ... }:

with lib;
if (systemCfg.desktop.type == "none") then
  { }
else {
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

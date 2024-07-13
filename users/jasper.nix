_:

{ username, email, ... }:

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

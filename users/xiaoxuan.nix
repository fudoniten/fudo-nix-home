inputs:

{
  username,
  email,
  home-directory ? null,
  ...
}:

systemCfg:

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  # Validate required arguments
  checkArgs =
    assert assertMsg (username != null && username != "") "username is required";
    assert assertMsg (
      systemCfg ? desktop && systemCfg.desktop ? type
    ) "systemCfg.desktop.type is required";
    assert assertMsg (builtins.elem systemCfg.desktop.type [
      "x"
      "wayland"
      "darwin"
      "none"
    ]) "systemCfg.desktop.type must be one of: x, wayland, darwin, none";
    null;

  inherit (pkgs.stdenv) isLinux;

  isGui = systemCfg.desktop.type != "none";
  isX = systemCfg.desktop.type == "x";

in
builtins.seq checkArgs {
  config = mkIf isGui {
    home = {
      inherit username;

      packages = with pkgs; [
        # Productivity and office
        abiword # Lightweight word processor

        # Learning
        anki # Flashcard application

        # System tools
        gnome-tweaks # GNOME customization tool

        # Web browsers
        google-chrome # Google Chrome browser

        # Communication
        mumble # Low-latency voice chat

        # Media
        spotify # Music streaming
        redshift # Screen color temperature

        # Utilities
        pv # Pipe viewer
        xclip # X11 clipboard utility

        # Theme packages
        graphite-cursors # Cursor theme
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
          '';
        };
      };
    };

    # Chinese (Simplified, Pinyin) input.
    #
    # GNOME runs IBus itself and only offers the engines the system installs
    # -- nixos-config adds ibus-libpinyin on GNOME hosts. This just puts it
    # in the input sources so it is there on first login: Super+Space
    # switches between English and 中文 (the indicator in the top bar shows
    # which is active), and Shift toggles English inside Pinyin mode.
    #
    # This used to run fcitx5 here, which cannot work under GNOME: GNOME
    # Shell only talks to IBus, and fcitx5's session variables pointed GTK
    # apps away from it, so neither one ended up usable.
    dconf.settings = mkIf isLinux {
      "org/gnome/desktop/input-sources" = {
        sources = [
          (hm.gvariant.mkTuple [
            "xkb"
            "us"
          ])
          (hm.gvariant.mkTuple [
            "ibus"
            "libpinyin"
          ])
        ];
      };
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

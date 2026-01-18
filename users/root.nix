inputs:

{ username, email, home-directory, ... }:

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

  commonPackages = with pkgs; [
    atop
    btrfs-progs
    cdrtools
    curl
    file
    git
    gnutls
    gnupg
    guile
    iptables
    lsof
    lshw
    mtr
    nix-prefetch-git
    nmap
    pciutils
    pwgen
    tmux
    unzip
  ];

in {
  imports = [ ];

  config = {
    programs.doom-emacs = {
      enable = true;
      desktopType = "none";
      doomSource = inputs.doom-emacs;
      doomConfigSource = inputs.niten-doom-config;
    };
    programs = {
      bash = {
        enable = true;
        enableVteIntegration = true;
      };

      git = {
        enable = true;
        userName = username;
        userEmail = email;
        ignores = [ "*~" ];
        extraConfig.pull.rebase = false;
      };
    };

    home = {
      inherit username;

      packages = commonPackages;

      sessionVariables = {
        ALTERNATE_EDITOR = "";

        HISTCONTROL = "ignoredups:ignorespace";
      };
    };

    systemd.user.tmpfiles.rules =
      [ "d ${home-directory}/.emacs.d/.local/etc/eshell 700 root - - -" ];
  };
}

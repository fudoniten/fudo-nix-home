inputs:

{ username, email, home-directory, ... }:

systemCfg:

{ config, lib, pkgs, ... }:

with lib;
let
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
  imports = [ (import ./common/niten-doom-emacs.nix inputs) ];

  config = {
    programs = {
      bash = {
        enable = true;
        enableVteIntegration = true;
      };

      git = {
        enable = true;
        userName = username;
        userEmail = user-email;
        ignores = [ "*~" ];
        extraConfig.pull.rebase = false;
      };
    };

    services = {
      emacs = {
        enable = true;
        package = doom-emacs-package;
        client.enable = true;
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
      [ "d ${home-dir}/.emacs.d/.local/etc/eshell 700 root - - -" ];
  };
}

inputs:

{ username, email, home-directory, ... }@userOpts:

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

in {
  config = {
    home = {
      inherit username;
      homeDirectory = home-directory;

      packages = with pkgs; [
        atop
        bind # for dig
        binutils
        btrfs-progs
        byobu
        curl
        file
        git
        inetutils
        iptables
        lshw
        lsof
        mkpasswd
        mosh
        mtr
        nmap
        parted
        pv
        pwgen
        stdenv
        tmux
        unzip
        usbutils
        vim
        wget
      ];
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
      };

      fzf = {
        enable = true;
        enableBashIntegration = true;
      };
    };
  };
}

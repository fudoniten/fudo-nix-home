_:

{ username, email, home-directory, ... }:

systemCfg:

{ config, lib, pkgs, ... }:

with lib; {
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
        userEmail = user-email;
      };

      fzf = {
        enable = true;
        enableBashIntegration = true;
      };
    };
  };
}

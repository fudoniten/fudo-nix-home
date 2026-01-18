inputs:

{ username, email, home-directory, ... }:

systemCfg:

{ config, lib, pkgs, ... }:

with lib;
let
  # Validate required arguments
  _ = assert assertMsg (username != null && username != "")
    "username is required";
    assert assertMsg (email != null && email != "")
    "email is required";
    assert assertMsg (home-directory != null && home-directory != "")
    "home-directory is required";
    null;

in {
  config = {
    home = {
      inherit username;
      homeDirectory = home-directory;

      packages = with pkgs; [
        # System monitoring
        atop                   # Advanced system monitor

        # Network utilities
        bind                   # DNS utilities (dig)
        mtr                    # Network diagnostic tool
        mosh                   # Mobile shell
        nmap                   # Network scanner
        inetutils              # Network utilities

        # Development and build tools
        binutils               # Binary utilities
        stdenv                 # Standard build environment

        # File system tools
        btrfs-progs            # Btrfs utilities

        # Terminal utilities
        byobu                  # Terminal multiplexer wrapper
        tmux                   # Terminal multiplexer
        file                   # Determine file types
        pv                     # Pipe viewer
        unzip                  # ZIP extraction

        # System tools
        curl                   # HTTP client
        git                    # Version control
        iptables               # Firewall management
        lshw                   # Hardware lister
        lsof                   # List open files
        mkpasswd               # Password generator
        parted                 # Partition editor
        pwgen                  # Password generator
        usbutils               # USB utilities
        vim                    # Text editor
        wget                   # File downloader
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

inputs:

{ username, email, home-directory, ... }:

systemCfg:

{ config, lib, pkgs, ... }:

with lib;
let
  # Validate required arguments
  _ = assert assertMsg (username != null && username != "")
    "username is required";
    assert assertMsg (email != null && email != "") "email is required";
    assert assertMsg (home-directory != null && home-directory != "")
      "home-directory is required";
    null;

in {
  config = {
    home = {
      inherit username;
      homeDirectory = home-directory;

      packages = with pkgs; [
        # Network utilities
        curl
        bind # DNS utilities (dig)
        net-tools
        nmap # Network scanner
        inetutils # Network utilities
        openssh
        wget

        # Development and build tools
        act # Test GitHub actions locally
        binutils # Binary utilities
        cmake
        gcc
        gh # GitHub tool
        gnumake
        nano
        nix
        nodejs
        python3
        stdenv # Standard build environment
        vim

        # Terminal utilities
        direnv # directory-specific environments
        file # Determine file types
        pv # Pipe viewer
        shellcheck # Shell linter
        tree # Dump directories as trees
        unzip # ZIP extraction

        # System tools
        btop
        curl # HTTP client
        git # Version control
        htop
        iproute2
        iptables # Firewall management
        kubectl
        lshw # Hardware lister
        lsof # List open files
        nix # Nix package manager
        mkpasswd # Password generator
        pwgen # Password generator
        tmux
        usbutils # USB utilities
        wget # File downloader

        # Text processing
        fd
        jless
        jq
        yq-go
        ripgrep
        fd
      ];
    };

    services.ssh-agent.enable = true;

    programs = { bash.enable = true; };
  };
}

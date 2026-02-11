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
        bind # DNS utilities (dig)
        nmap # Network scanner
        inetutils # Network utilities

        # Development and build tools
        act # Test GitHub actions locally
        binutils # Binary utilities
        gh # GitHub tool
        stdenv # Standard build environment

        # Terminal utilities
        direnv # directory-specific environments
        file # Determine file types
        jq # JSON tool
        pv # Pipe viewer
        ripgrep # Faster grep
        shellcheck # Shell linter
        tree # Dump directories as trees
        unzip # ZIP extraction
        yq # YAML tool

        # System tools
        curl # HTTP client
        git # Version control
        iptables # Firewall management
        lshw # Hardware lister
        lsof # List open files
        nix # Nix package manager
        mkpasswd # Password generator
        pwgen # Password generator
        usbutils # USB utilities
        wget # File downloader
      ];
    };

    programs = { bash.enable = true; };
  };
}

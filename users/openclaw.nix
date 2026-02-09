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
        binutils # Binary utilities
        stdenv # Standard build environment

        # Terminal utilities
        file # Determine file types
        pv # Pipe viewer
        unzip # ZIP extraction

        # System tools
        curl # HTTP client
        git # Version control
        iptables # Firewall management
        lshw # Hardware lister
        lsof # List open files
        mkpasswd # Password generator
        pwgen # Password generator
        usbutils # USB utilities
        wget # File downloader
      ];
    };

    programs = { bash.enable = true; };
  };
}

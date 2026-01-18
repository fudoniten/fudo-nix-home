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

  # Common system administration packages
  commonPackages = with pkgs; [
    # System monitoring
    atop                   # Advanced system monitor

    # File system tools
    btrfs-progs            # Btrfs utilities

    # CD/DVD utilities
    cdrtools               # CD/DVD recording utilities

    # HTTP and network
    curl                   # HTTP client

    # Utilities
    file                   # Determine file types

    # Version control
    git                    # Version control system

    # Security
    gnutls                 # TLS library
    gnupg                  # GNU Privacy Guard

    # Scripting
    guile                  # GNU Guile Scheme

    # Firewall
    iptables               # Firewall management

    # System info
    lsof                   # List open files
    lshw                   # Hardware lister

    # Network diagnostics
    mtr                    # Network diagnostic tool
    nmap                   # Network scanner

    # Nix tools
    nix-prefetch-git       # Fetch git repos for Nix

    # PCI utilities
    pciutils               # PCI utilities (lspci)

    # Password utilities
    pwgen                  # Password generator

    # Terminal utilities
    tmux                   # Terminal multiplexer
    unzip                  # ZIP extraction
  ];

in {
  imports = [ ];

  config = {
    # Doom Emacs configuration for root (headless mode)
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

      starship = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableInteractive = true;
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

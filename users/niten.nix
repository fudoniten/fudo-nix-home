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

  inherit (pkgs.stdenv) isLinux isDarwin;

  # Build Emacs packages from flake inputs
  # These packages are built using trivialBuild for simple Emacs Lisp packages

  # Polymuse - generative music composition engine
  # Provides tools for algorithmic music generation within Emacs
  polymusePackage = pkgs.emacsPackages.trivialBuild {
    pname = "polymuse";
    version = "0.1.0";
    src = inputs.polymuse;
    packageRequires = with pkgs.emacsPackages; [];
  };

  # Canon - music notation and composition tools
  # Works alongside polymuse for complete music creation workflow
  canonPackage = pkgs.emacsPackages.trivialBuild {
    pname = "canon";
    version = "0.1.0";
    src = inputs.canon-el;
    packageRequires = with pkgs.emacsPackages; [];
  };

  sessionEnvVariables = {
    ALTERNATE_EDITOR = "";

    HISTCONTROL = "ignoredups:ignorespace";

    EMACS_ORG_DIRECTORY = "$HOME/Notes";

    XDG_DATA_DIRS = "$XDG_DATA_DIRS:$HOME/.nix-profile/share/";
  };

  isGui = systemCfg.desktop.type != "none";
  isX = systemCfg.desktop.type == "x";

  # Common packages available on all systems (both GUI and headless)
  commonPackages = with pkgs; [
    # Network utilities
    dnsutils               # DNS lookup tools (dig, nslookup)
    curl                   # HTTP client
    wget                   # File downloader
    mosh                   # Mobile shell (better than SSH for unreliable connections)
    mtr                    # Network diagnostic tool (traceroute + ping)
    inetutils              # Network utilities (telnet, ftp, etc.)

    # Development tools - Build systems and compilers
    gcc                    # GNU Compiler Collection
    gnumake                # GNU Make build system
    cmake                  # Cross-platform build system
    stdenv                 # Standard build environment

    # Development tools - Languages and runtimes
    cargo                  # Rust package manager
    rustc                  # Rust compiler
    clojure                # Clojure programming language
    go                     # Go programming language
    guile                  # GNU Guile Scheme
    jdk                    # Java Development Kit
    ruby                   # Ruby programming language

    # Development tools - Nix ecosystem
    nil                    # Nix language server for IDE integration
    nixfmt-classic         # Nix code formatter
    nix-index              # Search for packages by executable name
    nix-prefetch-git       # Fetch git repositories for Nix
    nix-prefetch-github    # Fetch GitHub repositories for Nix
    bundix                 # Convert Ruby Gemfiles to Nix expressions
    manix                  # Search NixOS documentation
    statix                 # Nix linter for code quality

    # File and text utilities
    file                   # Determine file types
    enca                   # Encoding detector and converter
    unzip                  # ZIP archive extraction
    cdrtools               # CD/DVD recording utilities
    pv                     # Pipe viewer (monitor progress of data through pipes)

    # System utilities
    git                    # Version control system
    gnupg                  # GNU Privacy Guard (encryption)
    lsof                   # List open files
    pciutils               # PCI utilities (lspci)
    tmux                   # Terminal multiplexer
    fzf                    # Fuzzy finder
    pwgen                  # Password generator
    fortune                # Random fortune cookie messages

    # Document processing
    texlive.combined.scheme-full  # Complete LaTeX distribution
    graphviz               # Graph visualization (dot)

    # Data processing
    jq                     # JSON processor
    yq                     # YAML/XML processor

    # Container and cloud tools
    kubectl                # Kubernetes command-line tool
    fluxcd                 # GitOps Kubernetes operator
    fluxctl                # Flux control tool

    # Smart home and IoT
    home-assistant-cli     # Command-line interface for Home Assistant
    mqttui                 # Terminal UI for MQTT

    # Media
    yt-dlp                 # Video downloader (youtube-dl fork)

    # Security and privacy
    openssl                # SSL/TLS toolkit
    openssl.out            # OpenSSL outputs
    tor-browser            # Anonymous web browser

    # Specialized tools
    ipfs                   # InterPlanetary File System
    tio                    # Serial I/O terminal
    duf                    # Modern disk usage utility (better df)
  ];

  # GUI packages for all desktop environments
  commonGuiPackages = with pkgs; [
    spotify                # Music streaming service
  ];

  # Linux-specific packages (no GUI required)
  linuxPackages = with pkgs; [
    psensor                # Hardware sensor monitoring
  ];

  # Linux GUI applications
  linuxGuiPackages = with pkgs; [
    # GNOME Extensions
    gnomeExtensions.espresso  # Disable auto-suspend
    gnomeExtensions.forge     # Tiling window manager
    gnomeExtensions.vitals    # System monitoring

    # Terminals
    alacritty              # GPU-accelerated terminal emulator
    kitty                  # Fast, GPU-based terminal emulator
    cool-retro-term        # Retro-styled terminal emulator

    # Productivity and office
    abiword                # Lightweight word processor
    libreoffice            # Full office suite
    anki                   # Flashcard application for learning

    # Graphics and media
    imagemagick            # Image manipulation tools
    mplayer                # Media player
    rhythmbox              # Music player and organizer

    # Video editors
    libsForQt5.kdenlive    # Professional video editor
    openshot-qt            # Simple video editor
    shotcut                # Cross-platform video editor

    # Communication
    signal-desktop         # Secure messaging
    element-desktop        # Matrix protocol client
    mumble                 # Low-latency voice chat

    # Music and audio
    spotify-player         # Terminal UI for Spotify
    spotify-qt             # Qt-based Spotify client
    helvum                 # PipeWire patchbay (audio routing)

    # System tools
    gnome.dconf-editor     # GNOME configuration editor
    gnome.gnome-tweaks     # GNOME customization tool
    gparted                # Partition editor
    xclip                  # X11 clipboard utility
    playerctl              # Media player controller

    # Web browsers
    google-chrome          # Google Chrome browser

    # Hardware tools
    via                    # Keyboard firmware configuration
    vial                   # Open-source keyboard firmware tool

    # Games
    mindustry              # Tower defense strategy game
    openttd                # OpenTTD transport simulation

    # Audio libraries
    faudio                 # DirectX audio compatibility layer
    openal                 # 3D audio API
  ];

  # Font packages for Linux GUI systems
  fontPackages = optionals isLinux (with pkgs; [
    cantarell-fonts                    # GNOME default font
    dejavu_fonts                       # High-quality general-purpose fonts
    fira-code                          # Monospace font with programming ligatures
    fira-code-symbols                  # Additional symbols for Fira Code
    liberation_ttf                     # Metric-compatible with Arial/Times New Roman
    nerdfonts                          # Patched fonts with icons (for terminals/IDEs)
    proggyfonts                        # Small bitmap programming fonts
    terminus_font                      # Monospace bitmap font
    ubuntu_font_family                 # Ubuntu's font family
    ultimate-oldschool-pc-font-pack    # Retro computer fonts
    unifont                            # Unicode bitmap font
  ]);

in {
  imports = [ ];

  config = {
    # Doom Emacs configuration with custom packages
    programs.doom-emacs = {
      enable = true;
      desktopType = systemCfg.desktop.type;
      doomSource = inputs.doom-emacs;          # Doom Emacs framework
      doomConfigSource = inputs.niten-doom-config;  # Personal configuration
      emacsPackages = with pkgs.emacsPackages; [
        # AI and chatbots
        chatgpt-shell         # ChatGPT integration for Emacs

        # File management
        dirvish               # Modern file manager for Emacs

        # Web and protocols
        elpher                # Gopher and Gemini client
        restclient            # HTTP REST client

        # Programming language support
        flycheck-clj-kondo    # Clojure linting via clj-kondo
        pylint                # Python linting
        thrift                # Apache Thrift support

        # Cloud and infrastructure
        kubernetes            # Kubernetes integration
        hass                  # Home Assistant integration

        # Media
        spotify               # Spotify integration

        # Music composition (custom packages)
        polymusePackage       # Generative music composition engine
        canonPackage          # Music notation and composition tools
      ];
    };

    gtk.iconTheme = {
      package = pkgs.numix-icon-theme;
      name = "Numix";
    };

    programs = {
      bash = {
        enable = true;
        enableVteIntegration = true;
        enableCompletion = true;
        profileExtra = ''
          [[ -f $HOME/.profile_local ]] && . $HOME/.profile_local
        '';
      };

      git = {
        enable = true;
        userName = username;
        userEmail = email;
        ignores = [ "*~" ".DS_Store" ];
        extraConfig.pull.rebase = true;
      };

      gh = {
        enable = true;
        gitCredentialHelper.enable = true;
        settings = {
          editor = "emacsclient";
          git_protocol = "ssh";
        };
      };

      fzf = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
      };

      kitty = mkIf (isLinux && systemCfg.desktop.type != "none") {
        enable = true;
        settings = {
          copy_on_select = "clipboard";
          strip_trailing_spaces = "always";
          editor = "emacsclient -t";
          enable_audio_bell = false;
          scrollback_lines = 10000;
        };
        keybindings = let lead = "ctrl+super";
        in {
          "ctrl+shift+plus" = "no_op";
          "ctrl+shift+minus" = "no_op";
          "ctrl+shift+backspace" = "no_op";

          "${lead}+plus" = "change_font_size all +2.0";
          "${lead}+minus" = "change_font_size all -2.0";
          "${lead}+backspace" = "change_font_size all 0";

          "${lead}+left" = "previous_tab";
          "${lead}+right" = "next_tab";
          "${lead}+t" = "new_tab";
          "${lead}+alt+t" = "set_tab_title";
          "${lead}+x" = "detach_tab";
        };
      };

      firefox = mkIf isLinux {
        enable = systemCfg.desktop.type != "none";
        package =
          (pkgs.firefox.override { cfg = { enableGnomeExtensions = true; }; });
      };

      obs-studio.enable = isLinux && isGui;

      zsh.profileExtra = ''
        [[ -f $HOME/.profile_local ]] && . $HOME/.profile_local
      '';
    };

    xresources.properties = mkIf isX {
      "Xft.antialias" = 1;
      "Xft.autohint" = 0;
      "Xft.hinting" = 1;
      "Xft.hintstyle" = "hintfull";
      "Xft.lcdfilter" = "lcddefault";
    };

    # Services configuration (Linux only)
    services = mkIf isLinux {
      # GPG agent for encryption and signing
      gpg-agent.enable = true;

      # GNOME keyring for credential storage (GUI only)
      gnome-keyring.enable = isGui;

      # SuperCollider audio synthesis server (GUI only)
      # Used for real-time audio synthesis and algorithmic composition
      supercollider = {
        enable = isGui;
        port = 30300;        # Custom port (default is 57110)
        memory = 4096;       # 4GB memory allocation
      };

      # Syncthing continuous file synchronization
      syncthing = {
        enable = true;
        extraOptions = [ ];
      };
    };

    home = {
      inherit username;
      homeDirectory = home-directory;

      packages = commonPackages ++ (optionals isGui commonGuiPackages)
        ++ (optionals (isLinux && isGui) (linuxGuiPackages ++ fontPackages))
        ++ (optionals isLinux linuxPackages);

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

      sessionVariables = sessionEnvVariables;
    };

    systemd.user = mkIf isLinux { sessionVariables = sessionEnvVariables; };
  };
}

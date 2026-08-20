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
    assert assertMsg
      (builtins.elem systemCfg.desktop.type [ "x" "wayland" "darwin" "none" ])
      "systemCfg.desktop.type must be one of: x, wayland, darwin, none";
    null;

  inherit (pkgs.stdenv) isLinux isDarwin;

  mkExt = shortId: guid: {
    name = guid;
    value = {
      install_url =
        "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
      installation_mode = "normal_installed";
    };
  };

  # 1. Go to the extension's addons.mozilla.org page.
  # 2. Scroll to More information.
  # 3. Click Copy add-on ID. AMO currently shows that control directly on the RES page.
  zenExtensions = [
    # Proton Pass
    (mkExt "proton-pass" "78272b6fa58f4a1abaac99321d503a20@proton.me")
    # Bitwarden
    (mkExt "bitwarden-password-manager"
      "{446900e4-71c2-419f-a6a7-df9c091e268b}")
    # Karakeep self-hosted smart bookmarks
    (mkExt "karakeep" "addon@karakeep.app")
    # UBlock Origin
    (mkExt "ublock-origin" "uBlock0@raymondhill.net")
    # Multi-account containers--auto-open in container
    (mkExt "multi-account-containers" "@testpilot-containers")
    (mkExt "reddit-enhancement-suite" "jid1-xUfzOsOFlzSOXg@jetpack")
  ];

  # Zen's new native container implementation stores containers as part of
  # the workspace/session state (zen-sessions.jsonlz4) rather than reading
  # the legacy policies.json "Containers" key, so declaring them there (as
  # this config used to) only ever seeded the containers a fresh profile
  # started with. The zen-browser-flake Home Manager module below writes
  # these into zen-sessions.jsonlz4 directly, which is why each entry now
  # needs a stable numeric id (the underlying userContextId).
  zenContainers = {
    Xiaoxuan = {
      icon = "fingerprint";
      color = "pink";
      id = 1;
    };
    Jasper = {
      icon = "fingerprint";
      color = "purple";
      id = 2;
    };
    JasperGaming = {
      icon = "pet";
      color = "purple";
      id = 3;
    };
    Helen = {
      icon = "fingerprint";
      color = "yellow";
      id = 4;
    };
    Admin = {
      icon = "fingerprint";
      color = "red";
      id = 5;
    };
    xham = {
      icon = "food";
      color = "orange";
      id = 6;
    };
    LinkedIn = {
      icon = "circle";
      color = "blue";
      id = 7;
    };
    Google = {
      icon = "fence";
      color = "blue";
      id = 8;
    };
    Amazon = {
      icon = "cart";
      color = "yellow";
      id = 9;
    };
    Costco = {
      icon = "cart";
      color = "blue";
      id = 10;
    };
    AliExpress = {
      icon = "cart";
      color = "orange";
      id = 11;
    };
    Ebay = {
      icon = "cart";
      color = "purple";
      id = 12;
    };
    GitHub = {
      icon = "briefcase";
      color = "turquoise";
      id = 13;
    };
    Coinbase = {
      icon = "dollar";
      color = "blue";
      id = 14;
    };
    Kraken = {
      icon = "dollar";
      color = "pink";
      id = 15;
    };
    Hermes = {
      icon = "pet";
      color = "blue";
      id = 16;
    };
  };

  mkZenSearchEngine = template: alias: name: {
    inherit name;
    urls = [{ inherit template; }];
    definedAliases = [ alias ];
  };

  zenSearchEngines = {
    nixpkgs-packages = mkZenSearchEngine
      "https://search.nixos.org/packages?query={searchTerms}" "@np"
      "nixpkgs packages";
    nixos-options = mkZenSearchEngine
      "https://search.nixos.org/options?query={searchTerms}" "@no"
      "NixOS options";
    nixos-wiki = mkZenSearchEngine
      "https://wiki.nixos.org/w/index.php?search={searchTerms}" "@nw"
      "NixOS Wiki";
    amazon = mkZenSearchEngine "https://www.amazon.com/s?k={searchTerms}" "@a"
      "Amazon";
    wikipedia-en = mkZenSearchEngine
      "https://en.wikipedia.org/w/index.php?search={searchTerms}" "@w"
      "Wikipedia";
    wiktionary-en = mkZenSearchEngine
      "https://en.wiktionary.org/w/index.php?search={searchTerms}" "@wik"
      "Wiktionary";
    searxng = mkZenSearchEngine
      "https://search.kube.sea.fudo.link/search?q={searchTerms}" "@s"
      "SearXNG";
    # NB: the old policies.json config had this one pointed at Yahoo, which
    # looks like a copy/paste bug--fixed to actually search YouTube.
    youtube = mkZenSearchEngine
      "https://www.youtube.com/results?search_query={searchTerms}" "@y"
      "YouTube";
  };

  # Access unstable packages for bleeding-edge tools
  pkgsUnstable = inputs.nixpkgsUnstable.legacyPackages."${pkgs.system}";

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
    dnsutils # DNS lookup tools (dig, nslookup)
    curl # HTTP client
    wget # File downloader
    (mosh.override { openssh = openssh_gssapi; }) # Mobile shell
    mtr # Network diagnostic tool (traceroute + ping)
    inetutils # Network utilities (telnet, ftp, etc.)

    # Development tools - Build systems and compilers
    gcc # GNU Compiler Collection
    gnumake # GNU Make build system
    cmake # Cross-platform build system
    stdenv # Standard build environment

    # Development tools - Languages and runtimes
    cargo # Rust package manager
    rustc # Rust compiler
    clj-kondo # Clojure linter
    clojure # Clojure programming language
    go # Go programming language
    guile # GNU Guile Scheme
    jdk # Java Development Kit
    ruby # Ruby programming language

    # Secrets management (locket dependencies)
    age # Modern encryption tool for locket secrets

    # Development tools - Nix ecosystem
    nil # Nix language server for IDE integration
    nixfmt-classic # Nix code formatter
    nix-index # Search for packages by executable name
    nix-init # Attempt to generate full Nix package from URL
    nix-prefetch-git # Fetch git repositories for Nix
    nix-prefetch-github # Fetch GitHub repositories for Nix
    nurl # Generate Nix fetch clause from URL
    bundix # Convert Ruby Gemfiles to Nix expressions
    manix # Search NixOS documentation
    statix # Nix linter for code quality

    # File and text utilities
    comma # Run programs without installing them
    file # Determine file types
    enca # Encoding detector and converter
    unzip # ZIP archive extraction
    cdrtools # CD/DVD recording utilities
    pv # Pipe viewer (monitor progress through pipes)
    duf # Modern disk usage utility (better df)

    # System utilities
    git # Version control system
    gnupg # GNU Privacy Guard (encryption)
    lsof # List open files
    pciutils # PCI utilities (lspci)
    tmux # Terminal multiplexer
    fzf # Fuzzy finder
    pwgen # Password generator
    fortune # Random fortune cookie messages
    direnv # Environment switcher

    # AI development tools
    claude-code # Claude Code CLI
    pkgsUnstable.opencode # OpenCode CLI

    # Document processing
    texlive.combined.scheme-full # Complete LaTeX distribution
    graphviz # Graph visualization (dot)

    # Data processing
    jq # JSON processor
    yq # YAML/XML processor

    # Container and cloud tools
    kubectl # Kubernetes command-line tool
    fluxcd # GitOps Kubernetes operator
    flux # Flux control tool

    # Smart home and IoT
    home-assistant-cli # Command-line interface for Home Assistant
    mqttui # Terminal UI for MQTT

    # Media
    yt-dlp # Video downloader (youtube-dl fork)
    pipewire # Audio/video routing
    pipewire.jack # JACK compatibility

    # Security and privacy
    openssl # SSL/TLS toolkit
    openssl.out # OpenSSL outputs
    proton-pass-cli # Proton CLI UI
    tor-browser # Anonymous web browser

    # Specialized tools
    kubo # IPFS implementation
    tio # Serial I/O terminal
  ];

  # GUI packages for all desktop environments
  commonGuiPackages = with pkgs;
    [
      spotify # Music streaming service
    ];

  # Linux-specific packages (no GUI required)
  linuxPackages = with pkgs; [ ];

  # Linux GUI applications
  linuxGuiPackages = with pkgs; [
    # GNOME Extensions
    gnomeExtensions.forge # Tiling window manager
    gnomeExtensions.vitals # System monitoring

    # Terminals
    alacritty # GPU-accelerated terminal emulator
    kitty # Fast, GPU-based terminal emulator
    cool-retro-term # Retro-styled terminal emulator

    # Productivity and office
    abiword # Lightweight word processor
    libreoffice # Full office suite

    # Graphics and media
    imagemagick # Image manipulation tools
    mplayer # Media player
    rhythmbox # Music player and organizer

    # Video editors
    kdePackages.kdenlive # Professional video editor
    shotcut # Cross-platform video editor

    # Communication
    signal-desktop # Secure messaging
    mumble # Low-latency voice chat

    # Music and audio
    spotify-player # Terminal UI for Spotify
    spotify-qt # Qt-based Spotify client
    crosspipe # PipeWire patchbay (audio routing)

    # System tools
    dconf-editor # GNOME configuration editor
    gnome-tweaks # GNOME customization tool
    gparted # Partition editor
    evince # Document reader
    sops # Encryption tool for Kubernetes
    xclip # X11 clipboard utility
    playerctl # Media player controller

    # Web browsers
    google-chrome # Google Chrome browser

    # Hardware tools
    via # Keyboard firmware configuration
    vial # Open-source keyboard firmware tool

    # Games
    mindustry # Tower defense strategy game
    openttd # OpenTTD transport simulation
    heroic # Game launcher
    lutris # Game launcher
    prismlauncher # Minecraft launcher
    gogdl # GOG downloader
    mcpelauncher-client # Minecraft launcher
    waylandcraft

    gnome-mines # Minesweeper
    gnome-mahjongg # Mahjong solitaire
    gnome-sudoku # Sudoku puzzle game
    gnome-tetravex # Tetris-like puzzle
    gnome-klotski # Sliding block puzzle
    gnome-taquin # Sliding puzzle game
    aisleriot # Solitaire card games
    hitori # Logic puzzle game
    iagno # Reversi/Othello game
    quadrapassel # Tetris clone
    swell-foop # Puzzle game

    # Audio libraries
    faudio # DirectX audio compatibility layer
    openal # 3D audio API
  ];

  # Font packages for Linux GUI systems
  fontPackages = optionals isLinux ((with pkgs; [
    cantarell-fonts # GNOME default font
    dejavu_fonts # High-quality general-purpose fonts
    fira-code # Monospace font with programming ligatures
    fira-code-symbols # Additional symbols for Fira Code
    liberation_ttf # Metric-compatible with Arial/Times New Roman
    proggyfonts # Small bitmap programming fonts
    terminus_font # Monospace bitmap font
    ubuntu-classic # Ubuntu's font family
    ultimate-oldschool-pc-font-pack # Retro computer fonts
    unifont # Unicode bitmap font
  ]) ++ (with pkgs.nerd-fonts; [
    pkgs.nerd-fonts."_0xproto"
    pkgs.nerd-fonts."_3270"
    adwaita-mono
    agave
    anonymice
    arimo
    atkynson-mono
    aurulent-sans-mono
    bigblue-terminal
    bitstream-vera-sans-mono
    blex-mono
    caskaydia-cove
    caskaydia-mono
    code-new-roman
    comic-shanns-mono
    commit-mono
    cousine
    d2coding
    daddy-time-mono
    dejavu-sans-mono
    departure-mono
    droid-sans-mono
    envy-code-r
    fantasque-sans-mono
    fira-code
    fira-mono
    geist-mono
    go-mono
    gohufont
    hack
    hasklug
    heavy-data
    hurmit
    im-writing
    inconsolata
    inconsolata-go
    inconsolata-lgc
    intone-mono
    iosevka
    iosevka-term
    iosevka-term-slab
    jetbrains-mono
    lekton
    liberation
    lilex
    martian-mono
    meslo-lg
    monaspace
    monofur
    monoid
    mononoki
    pkgs.nerd-fonts."m+"
    noto
    open-dyslexic
    overpass
    profont
    proggy-clean-tt
    recursive-mono
    roboto-mono
    shure-tech-mono
    sauce-code-pro
    space-mono
    symbols-only
    terminess-ttf
    tinos
    ubuntu
    ubuntu-mono
    ubuntu-sans
    victor-mono
    zed-mono
  ]));

in {
  imports = [ inputs.zen-browser.homeModules.beta ];

  config = {
    # Doom Emacs configuration
    programs.doom-emacs = {
      enable = true;
      desktopType = systemCfg.desktop.type;
      doomSource = inputs.doom-emacs;
      doomConfigSource = inputs.niten-doom-config;
    };

    # StumpWM window manager (X11 only)
    programs.stumpwm = mkIf (systemCfg.desktop.type == "x") { enable = true; };

    gtk = {
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };

      theme = {
        package = pkgs.graphite-gtk-theme;
        name = "Graphite-Dark-Rimless";
      };
    };

    programs = {
      bash = {
        enable = true;
        enableVteIntegration = true;
        enableCompletion = true;
        profileExtra = ''
          [[ -f $HOME/.profile_local ]] && . $HOME/.profile_local
        '';
        initExtra = ''
          __set_xterm_title() {
            local dir="''${PWD/#$HOME/~}"
            printf '\033]0;%s:%s\007' "$HOSTNAME" "$dir"
          }

          case "$TERM" in
            xterm*|rxvt*|screen*|tmux*)
              if [[ -n "''${PROMPT_COMMAND-}" ]]; then
                PROMPT_COMMAND="__set_xterm_title; $PROMPT_COMMAND"
              else
                PROMPT_COMMAND="__set_xterm_title"
              fi
              ;;
          esac
        '';
      };

      starship = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableInteractive = true;
        settings = {
          directory = {
            truncation_length = 0;
            truncate_to_repo = true;
            fish_style_pwd_dir_length = 3;
          };
        };
      };

      direnv = {
        enable = true;
        enableBashIntegration = true;
        nix-direnv.enable = true;
      };

      git = {
        enable = true;
        settings = {
          user = {
            name = username;
            email = email;
          };
          pull.rebase = true;
        };
        ignores = [ "*~" ".DS_Store" ];
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

      # NB: containers, workspaces, pins, and keyboard shortcuts below are
      # written into zen-sessions.jsonlz4 by the activation script (decompress
      # -> edit with jq -> recompress), so close Zen before `home-manager
      # switch` whenever one of those changes--otherwise the running browser
      # can overwrite the freshly-written state on exit.
      zen-browser = mkIf (isLinux && isGui) {
        enable = true;

        policies = {
          DisableTelemetry = true;
          DisablePocket = true;
          OfferToSaveLogins = false;

          DNSOverHTTPS = {
            Enabled = false;
            Locked = true;
          };

          ExtensionSettings = builtins.listToAttrs zenExtensions;

          Preferences = mapAttrs (_: value: {
            Value = value;
            Status = "locked";
          }) {
            "browser.urlbar.suggest.quicksuggest.sponsored" = false;
            "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
            "browser.urlbar.suggest.trending" = false;
            "browser.urlbar.suggest.yelp" = false;
            "browser.urlbar.quicksuggest.enabled" = false;
            "browser.ml.chat.enabled" = false;
            # Firefox Containers--Zen's native container UI depends on this.
            "privacy.userContext.enabled" = true;
            "privacy.userContext.ui.enabled" = true;
          };
        };

        profiles.default = {
          containersForce = true;
          containers = zenContainers;

          search = {
            force = true;
            default = "google";
            engines = zenSearchEngines;
          };
        };
      };

      obs-studio.enable = isLinux && isGui;

      ssh = {
        enable = true;
        package = pkgs.openssh_hpnWithKerberos;
        matchBlocks."*" = {
          addKeysToAgent = "yes";
          compression = true;
          controlMaster = "yes";
          forwardAgent = true;
        };
      };

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

    stylix = mkIf (isLinux && isGui) {
      cursor = mkForce {
        package = pkgs.graphite-cursors;
        name = "graphite-dark";
        size = 16;
      };

      opacity = {
        applications = 1.0;
        desktop = 1.0;
        popups = 1.0;
        terminal = 0.9;
      };

      fonts = with pkgs; {
        serif = mkDefault {
          package = liberation_ttf;
          name = "Liberation Serif";
        };
        sansSerif = mkDefault {
          package = oxanium;
          name = "Oxanium";
        };
        monospace = mkDefault {
          package = nerdfonts;
          name = "Iosevka Nerd Font";
        };
        emoji = mkDefault {
          package = noto-fonts-emoji;
          name = "Noto Color Emoji";
        };
      };
    };

    # Services configuration (Linux only)
    services = mkIf isLinux {
      # GPG agent for encryption and signing
      gpg-agent.enable = true;

      # SSH agent for authentication
      ssh-agent.enable = true;

      # GNOME keyring for credential storage (GUI only)
      # SSH agent component disabled - using dedicated SSH agent instead
      gnome-keyring = {
        enable = isGui;
        components = mkIf isGui [ "pkcs11" "secrets" ];
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
        ++ (optionals isLinux linuxPackages) ++ (with pkgs; [
          graphite-cursors
          graphite-gtk-theme
          papirus-icon-theme
        ]);

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

      sessionVariables = sessionEnvVariables // {
        GTK_THEME = "Graphite-Dark-Rimless";
      } // (optionalAttrs isLinux {
        # Override GNOME Keyring's SSH_AUTH_SOCK to use our SSH agent
        SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/ssh-agent";
        # Disable GNOME Keyring's SSH agent component
        # This prevents COSMIC, GNOME, and other DEs from starting keyring's SSH agent
        GSM_SKIP_SSH_AGENT_WORKAROUND = "1";
      });
    };

    systemd.user = mkIf isLinux {
      sessionVariables = sessionEnvVariables // {
        # Override GNOME Keyring's SSH_AUTH_SOCK to use our SSH agent
        SSH_AUTH_SOCK = "%t/ssh-agent";
        # Disable GNOME Keyring's SSH agent component  
        GSM_SKIP_SSH_AGENT_WORKAROUND = "1";
      };

      # Service to export SSH_AUTH_SOCK to the systemd user environment
      # This ensures all applications (graphical and console) use the correct SSH agent
      # Works across COSMIC, GNOME, Wayland, X11, and console-only environments
      services.ssh-agent-env = {
        Unit = {
          Description = "Export SSH agent environment to systemd user session";
          After = [ "ssh-agent.service" ];
          # Start before graphical session so environment is set early
          Before = [ "graphical-session.target" ];
        };

        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          # Set SSH_AUTH_SOCK in systemd user environment
          # This overrides COSMIC/GNOME/other DE defaults that might set SSH_AUTH_SOCK to keyring
          ExecStart = ''
            ${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl --user set-environment SSH_AUTH_SOCK=%t/ssh-agent; \
            if command -v dbus-update-activation-environment >/dev/null 2>&1; then \
              ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd SSH_AUTH_SOCK; \
            fi'
          '';
          ExecStop =
            "${pkgs.systemd}/bin/systemctl --user unset-environment SSH_AUTH_SOCK";
        };

        Install = {
          # Start with default target (works for both graphical and console-only)
          # For graphical sessions: starts before DE and sets environment early
          # For console-only: runs on login and exports to systemd user session
          WantedBy = [ "default.target" ];
        };
      };
    };

    # Use systemd environment.d to set SSH_AUTH_SOCK very early in the boot process
    # This overrides GNOME Keyring's PAM module which tries to set SSH_AUTH_SOCK during login
    # Works for COSMIC, GNOME, and all other desktop environments
    xdg.configFile = {
      "environment.d/10-ssh-agent.conf" = mkIf isLinux {
        text = ''
          SSH_AUTH_SOCK=''${XDG_RUNTIME_DIR}/ssh-agent
          GSM_SKIP_SSH_AGENT_WORKAROUND=1
        '';
      };
    };

    # Enable VR configuration (OpenXR and OpenComposite)
    # Configured via the fudo.vr module for Meta Quest 3 support
    fudo.vr.enable = isLinux && isGui;
  };
}

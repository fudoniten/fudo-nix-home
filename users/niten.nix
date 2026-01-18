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
  polymusePackage = pkgs.emacsPackages.trivialBuild {
    pname = "polymuse";
    version = "0.1.0";
    src = inputs.polymuse;
    packageRequires = with pkgs.emacsPackages; [];
  };

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

  commonPackages = with pkgs; [
    dnsutils # for dig
    bundix # gemfile -> nix
    cdrtools
    cargo # rust
    clojure
    cmake
    curl
    duf # fancy df
    enca # encoding detector
    file
    fluxcd
    fluxctl
    fortune
    fzf
    gcc
    git
    gnumake
    gnupg
    go
    graphviz
    guile
    home-assistant-cli
    inetutils
    ipfs
    jdk
    jq # command-line JSON parser
    lsof
    kubectl
    manix # nixos doc searcher
    mosh
    mtr # network diagnosis tool
    mqttui # CLI MQTT client
    nil # nix lsp server
    nixfmt-classic # format nix files
    nix-index # search by executable
    nix-prefetch-git
    nix-prefetch-github
    openssl # Not sure which I need?
    openssl.out
    pciutils
    pv # dd with info
    pwgen
    ruby
    rustc
    statix # nix linter
    stdenv
    texlive.combined.scheme-full
    tio # Serial IO
    tmux
    tor-browser
    unzip
    wget
    yt-dlp
    yq # yaml processor
  ];

  commonGuiPackages = with pkgs; [ spotify ];

  linuxPackages = with pkgs; [ psensor ];

  linuxGuiPackages = with pkgs; [
    gnomeExtensions.espresso
    gnomeExtensions.forge
    gnomeExtensions.vitals

    abiword
    alacritty # terminal
    anki # flashcards
    cool-retro-term
    faudio # direct-x audio?
    gnome.dconf-editor # for gnome dconf config
    gnome.gnome-tweaks
    google-chrome
    gparted
    helvum # pipeaudio switch panel
    imagemagick
    kitty # terminal
    libreoffice
    mindustry
    mplayer
    mumble
    openal
    openttd
    playerctl
    rhythmbox
    signal-desktop
    spotify-player
    spotify-qt
    via # keyboard firmware tool
    vial # another keyboard firmware tool
    xclip
    element-desktop # matrix client

    # Video editors
    libsForQt5.kdenlive
    openshot-qt
    shotcut
  ];

  fontPackages = optionals isLinux (with pkgs; [
    cantarell-fonts
    dejavu_fonts
    fira-code
    fira-code-symbols
    liberation_ttf
    nerdfonts
    proggyfonts
    terminus_font
    ubuntu_font_family
    ultimate-oldschool-pc-font-pack
    unifont
  ]);

in {
  imports = [ ];

  config = {
    programs.doom-emacs = {
      enable = true;
      desktopType = systemCfg.desktop.type;
      doomSource = inputs.doom-emacs;
      doomConfigSource = inputs.niten-doom-config;
      emacsPackages = with pkgs.emacsPackages; [
        chatgpt-shell
        dirvish
        elpher
        flycheck-clj-kondo
        hass
        kubernetes
        pylint
        restclient
        spotify
        thrift
        polymusePackage
        canonPackage
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

    services = mkIf isLinux {
      gpg-agent.enable = true;

      gnome-keyring.enable = isGui;

      supercollider = {
        enable = isGui;
        port = 30300;
        memory = 4096;
      };

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

# Doom Emacs Home Manager Module
#
# This module provides declarative configuration for Doom Emacs, an Emacs
# framework that provides sensible defaults and a focus on performance.
#
# Features:
# - Automatic installation and configuration of Doom Emacs
# - Platform-specific Emacs package selection (X11, Wayland, macOS, headless)
# - Emacs daemon service management (systemd on Linux, launchd on macOS)
# - Custom state directory support for read-only or noexec home directories
# - Integration with shell environments (bash, zsh)
# - Configurable extra packages and dependencies
# - Polymuse integration for music composition
#
# Usage:
#   programs.doom-emacs = {
#     enable = true;
#     desktopType = "wayland";  # or "x", "darwin", "none"
#     doomSource = inputs.doom-emacs;
#     doomConfigSource = inputs.my-doom-config;
#     emacsPackages = epkgs: [ epkgs.org-roam ... ];
#   };

{ inputs, ... }:

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.programs.doom-emacs;

  # Determine state directory for Doom Emacs local files
  stateDir = if cfg.stateDirectory != null then
    cfg.stateDirectory
  else
    "${config.xdg.dataHome}/doom";

  # Default Doom Emacs environment setup
  doomEmacsEnv = ''
    export PATH="${config.xdg.configHome}/emacs/bin:${config.xdg.configHome}/doom/bin:$PATH"
    export DOOMLOCALDIR="${stateDir}"
  '';

  # Access unstable packages for bleeding-edge tools
  pkgsUnstable = inputs.nixpkgsUnstable.legacyPackages."${pkgs.system}";

  # Default Emacs dependencies
  # These packages are required for Doom Emacs to function properly
  defaultEmacsDeps = with pkgs; [
    (aspellWithDicts
      (ds: with ds; [ en en-computers en-science ])) # Spell checking
    babashka # Clojure scripting
    basedpyright # Python language server
    bashInteractive # Shell integration
    black # Python formatting
    clang-tools
    cljfmt
    clojure # Clojure runtime
    clojure-lsp # Clojure language server
    coreutils # Core GNU utilities
    curl # HTTP client
    delta
    diffutils # Diff tools (for version control)
    doas # Sudo alternative
    editorconfig-core-c # EditorConfig support
    fd # Fast file finder (used by Doom's fuzzy finder)
    findutils
    git # Version control (required by Doom)
    gnugrep
    gnugrep # GNU grep (used by various Doom features)
    gnutar # Archive extraction
    gnutls # TLS support for package downloads
    gomodifytags
    gopls # Go language server
    gore
    gotests
    imagemagick # Image processing (for inline image display)
    isort
    multimarkdown
    nix # Nix for nix-mode
    nodePackages.prettier # Code formatter for web languages
    openssh_hpnWithKerberos # SSH support (for TRAMP remote editing)
    pandoc
    python3 # Python runtime
    racket
    (ripgrep.override { withPCRE2 = true; }) # Fast search with PCRE2 support
    ruff # Python linting LSP
    rust-analyzer
    shellcheck
    shfmt
    sqlite # Database (used by org-roam and other packages)
    supercollider # Audio synthesis for music composition
    xclip # X11 clipboard integration
    zstd # Compression (for package caching)
  ] ++ [ pkgsUnstable.opencode ];

  defaultEmacsPkgs = epkgs:
    with epkgs; [
      agent-shell
      aidermacs
      babashka
      bash-completion
      canon
      capf-autosuggest
      consult
      diff-hl
      dirvish
      doom-two-tone-themes
      eat
      edit-server
      ellama
      elpher
      embark
      embark-consult
      eshell-syntax-highlighting
      flycheck-clj-kondo
      git-link
      gptel
      hass
      inf-clojure
      kubernetes
      magit-delta
      marginalia
      nix-mode
      nix-ts-mode
      noflet
      orderless
      org-modern
      org-roam
      paredit
      pet
      polymuse
      pylint
      restclient
      sly-asdf
      sly-quicklisp
      spotify
      stimmung-themes
      thrift
      transient
      treesit-auto
      typewrite
      vertico
      wgrep
    ];

  # Linux-specific dependencies
  defaultLinuxDeps = with pkgs;
    [
      sbcl # Steel Bank Common Lisp (for some Emacs packages)
    ];

  # Build emacs with packages using custom overlay
  myEmacsWithPackages = emacs:
    let
      baseEmacsPkgs = pkgs.emacsPackagesFor emacs;

      # Override scope to add custom packages
      updatedEmacsPkgs = baseEmacsPkgs.overrideScope (eself: esuper:
        let
          # Custom theme package
          doom-two-tone-themes = eself.trivialBuild {
            pname = "doom-two-tone-themes";
            version = "0.1";
            src = pkgs.fetchFromGitHub {
              owner = "eliraz-refael";
              repo = "doom-two-tone-themes";
              rev = "cbc3d52fb6db72a82734445076980d8e74c20293";
              sha256 = "sha256-Cgt2v6uQMl2Ub1uUWucOrRfHw9cY7GkW5u5Ua+Prnz8=";
            };

            installPhase = ''
              mkdir -p $out/share/emacs/site-lisp/themes
              cp ./doom-two-tone-themes.el $out/share/emacs/site-lisp/doom-two-tone-themes.el
              cp -R ./themes $out/share/emacs/site-lisp/
            '';

            meta = {
              homepage =
                "https://github.com/eliraz-refael/doom-two-tone-themes";
              description = "Two-toned themes for Doom Emacs.";
              license = pkgs.lib.licenses.gpl3Plus;
            };
          };

          # Polymuse music composition packages from separate flakes
          polymusePkg = inputs.polymuse.packages."${pkgs.system}".default;
          typewritePkg = inputs.typewrite.packages."${pkgs.system}".default;
          canonPkg = inputs.canon.packages."${pkgs.system}".default;

        in esuper // {
          inherit doom-two-tone-themes;

          # Polymuse packages for music composition
          # Use the packages directly from the flake outputs
          polymuse = polymusePkg;
          canon = canonPkg;
          typewrite = typewritePkg;
        });

    in updatedEmacsPkgs.withPackages cfg.emacsPackages;

  # Determine the appropriate emacs package based on platform and desktop type
  emacsPackage = let
    basePackage = if cfg.package != null then
      cfg.package
    else if pkgs.stdenv.isDarwin then
      pkgs.emacs29
    else if cfg.desktopType == "none" then
      pkgs.emacs-nox
    else if cfg.desktopType == "wayland" then
      pkgs.emacs-pgtk
    else
      pkgs.emacs-gtk;
  in myEmacsWithPackages basePackage;

in {
  options.programs.doom-emacs = with types; {
    enable = mkEnableOption "Doom Emacs configuration";

    package = mkOption {
      type = nullOr package;
      default = null;
      description =
        "The Emacs package to use. If null, automatically determined based on platform and desktop type.";
    };

    desktopType = mkOption {
      type = enum [ "x" "wayland" "darwin" "none" ];
      default = "none";
      description =
        "The desktop type (x, wayland, darwin, or none). Affects which Emacs package is used.";
    };

    doomSource = mkOption {
      type = package;
      description = "The Doom Emacs source package.";
    };

    doomConfigSource = mkOption {
      type = package;
      description = "The Doom Emacs configuration source.";
    };

    extraPackages = mkOption {
      type = listOf package;
      default = [ ];
      description = "Extra packages to install alongside Doom Emacs.";
      example = literalExpression "with pkgs; [ nodejs python3 ]";
    };

    extraDependencies = mkOption {
      type = listOf package;
      default = [ ];
      description = "Extra dependencies for Emacs functionality.";
      example = literalExpression "with pkgs; [ terraform-ls rust-analyzer ]";
    };

    emacsPackages = mkOption {
      type = functionTo (listOf package);
      default = defaultEmacsPkgs;
      description =
        "Function that takes emacs packages and returns list of packages to install.";
    };

    enableDaemon = mkOption {
      type = bool;
      default = true;
      description = "Enable the Emacs daemon service.";
    };

    defaultEditor = mkOption {
      type = bool;
      default = true;
      description = "Set Emacs as the default editor.";
    };

    extraAliases = mkOption {
      type = attrsOf str;
      default = { };
      description = "Extra shell aliases for Emacs.";
      example = literalExpression ''{ doom = "~/.config/emacs/bin/doom"; }'';
    };

    extraEnv = mkOption {
      type = attrsOf str;
      default = { };
      description = "Extra environment variables for Doom Emacs.";
      example = literalExpression ''{ DOOMDIR = "~/.doom.d"; }'';
    };

    syncTimeout = mkOption {
      type = str;
      default = "30min";
      description = "Timeout for Doom sync operation on daemon startup.";
    };

    stateDirectory = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Directory for Doom Emacs state files (compiled packages, cache, etc.).
        This directory must be writable and executable.

        Useful when home directory is mounted read-only or noexec.
        If null, defaults to XDG data directory (~/.local/share/doom).

        Example: "/var/lib/doom-state" or "/tmp/doom-state"
      '';
      example = "/var/lib/doom-state";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # Common configuration for all platforms
    {
      xdg.configFile."doom" = {
        source = cfg.doomConfigSource;
        force = true;
      };

      programs = {
        bash.bashrcExtra = doomEmacsEnv;
        zsh.envExtra = doomEmacsEnv;
      };

      home = {
        activation.installDoomEmacs =
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if [ ! -d ${config.xdg.configHome}/emacs ]; then
              mkdir -p ${config.xdg.configHome}/emacs
            fi
            ${pkgs.rsync}/bin/rsync -avz --chmod=D2755,F744 ${cfg.doomSource}/ ${config.xdg.configHome}/emacs/

            # Create state directory if it doesn't exist
            if [ ! -d ${stateDir} ]; then
              mkdir -p ${stateDir}
            fi
          '';

        packages = [ emacsPackage ] ++ defaultEmacsDeps ++ cfg.extraDependencies
          ++ cfg.extraPackages
          ++ (optionals pkgs.stdenv.isLinux defaultLinuxDeps);

        sessionVariables = {
          DOOMLOCALDIR = stateDir;
          DOOM_EMACS_SITE_PATH = "${config.xdg.configHome}/doom/site.d";
          DOOM_EMACS_LOCAL_PATH = "${config.xdg.configHome}/emacs-local";
        } // cfg.extraEnv;

        shellAliases = {
          emacs = "emacs --init-directory=${config.xdg.configHome}/emacs";
          e = "emacsclient --create-frame --tty";
          ew = "emacsclient --create-frame";
        } // cfg.extraAliases;
      };
    }

    # Linux-specific configuration
    (mkIf pkgs.stdenv.isLinux {
      systemd.user.services.emacs = mkIf cfg.enableDaemon {
        Service = {
          Environment = let
            binPath = makeBinPath ([ emacsPackage ] ++ config.home.packages);
          in [ "PATH=$PATH:${binPath}" "DOOMLOCALDIR=${stateDir}" ];
          ExecStartPre = pkgs.writeShellScript "run-doom-sync" ''
            # Ensure state directory exists
            if [ ! -d ${stateDir} ]; then
              mkdir -p ${stateDir}
            fi

            until [ -d ${config.xdg.configHome}/emacs ]; do sleep 1; done

            export DOOMLOCALDIR="${stateDir}"
            ${pkgs.bash}/bin/bash ${config.xdg.configHome}/emacs/bin/doom sync

            if [ -d $HOME/.emacs.d ]; then
              echo "removing old emacs config in ~/.emacs.d"
            fi
          '';
          TimeoutStartSec = cfg.syncTimeout;
        };
      };

      services.emacs = mkIf cfg.enableDaemon {
        enable = true;
        package = emacsPackage;
        client = {
          enable = true;
          arguments = [ "--create-frame" ];
        };
        extraOptions = [ "--init-directory=${config.xdg.configHome}/emacs" ];
        defaultEditor = cfg.defaultEditor;
        startWithUserSession = true;
      };
    })

    # macOS-specific configuration
    (mkIf pkgs.stdenv.isDarwin {
      home.packages = [ emacsPackage ] ++ defaultEmacsDeps
        ++ cfg.extraDependencies ++ cfg.extraPackages;

      launchd = mkIf cfg.enableDaemon {
        enable = true;
        agents.emacs = {
          enable = true;
          config = {
            ProgramArguments = [
              "${pkgs.bash}/bin/bash"
              "-l"
              "-c"
              "export DOOMLOCALDIR='${stateDir}' && ${emacsPackage}/bin/emacs --fg-daemon"
            ];
            EnvironmentVariables = { DOOMLOCALDIR = stateDir; };
            StandardErrorPath =
              "${config.home.homeDirectory}/Library/Logs/emacs-daemon.stderr.log";
            StandardOutPath =
              "${config.home.homeDirectory}/Library/Logs/emacs-daemon.stdout.log";
            RunAtLoad = true;
            KeepAlive = true;
          };
        };
      };
    })
  ]);
}

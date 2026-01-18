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

  # Default Emacs dependencies
  defaultEmacsDeps = with pkgs; [
    git
    (ripgrep.override { withPCRE2 = true; })
    gnutls
    gopls
    fd
    imagemagick
    zstd
    (aspellWithDicts (ds: with ds; [ en en-computers en-science ]))
    editorconfig-core-c
    sqlite
    xclip
    openssh
    diffutils
    coreutils
    gnutar
    bashInteractive
    clojure-lsp
    clojure
    curl
    gnugrep
    nodePackages.prettier
  ];

  # Linux-specific dependencies
  defaultLinuxDeps = with pkgs; [ sbcl ];

  # Build emacs with packages
  myEmacsPackagesFor = emacs:
    (pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs:
      with epkgs; cfg.emacsPackages);

  # Determine the appropriate emacs package based on platform and desktop type
  emacsPackage = let
    basePackage =
      if cfg.package != null then
        cfg.package
      else if pkgs.stdenv.isDarwin then
        pkgs.emacs29
      else if cfg.desktopType == "none" then
        pkgs.emacs-nox
      else if cfg.desktopType == "wayland" then
        pkgs.emacs29-pgtk
      else
        pkgs.emacs-gtk;
  in myEmacsPackagesFor basePackage;

in {
  options.programs.doom-emacs = with types; {
    enable = mkEnableOption "Doom Emacs configuration";

    package = mkOption {
      type = nullOr package;
      default = null;
      description = "The Emacs package to use. If null, automatically determined based on platform and desktop type.";
    };

    desktopType = mkOption {
      type = enum [ "x" "wayland" "darwin" "none" ];
      default = "none";
      description = "The desktop type (x, wayland, darwin, or none). Affects which Emacs package is used.";
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
      type = listOf package;
      default = with pkgs.emacsPackages; [
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
      ];
      description = "Emacs packages to install.";
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
      example = literalExpression "{ doom = \"~/.config/emacs/bin/doom\"; }";
    };

    extraEnv = mkOption {
      type = attrsOf str;
      default = { };
      description = "Extra environment variables for Doom Emacs.";
      example = literalExpression "{ DOOMDIR = \"~/.doom.d\"; }";
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

        packages = [ emacsPackage ] ++ defaultEmacsDeps ++ cfg.extraDependencies ++ cfg.extraPackages
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
          in [
            "PATH=$PATH:${binPath}"
            "DOOMLOCALDIR=${stateDir}"
          ];
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
            EnvironmentVariables = {
              DOOMLOCALDIR = stateDir;
            };
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

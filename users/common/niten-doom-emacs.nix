systemCfg:

{ doom-emacs, niten-doom-config, nixpkgsUnstable, ... }:

userPackages:

{ config, lib, pkgs, ... }:

with lib;
let
  pkgsUnstable = nixpkgsUnstable.legacyPackages."${pkgs.system}";

  doomEmacsEnv = ''
    export PATH="${config.xdg.configHome}/emacs/bin:${config.xdg.configHome}/doom/bin:$PATH"
  '';

  emacsDeps = with pkgs;
    [
      (aspellWithDicts (ds: with ds; [ en en-computers en-science ]))
      pkgsUnstable.aider-chat
      babashka
      bashInteractive
      basedpyright # python lsp
      clojure
      clojure-lsp
      coreutils
      curl
      diffutils
      doas
      editorconfig-core-c
      fd
      git
      gnugrep
      gnutar
      gnutls
      gopls
      imagemagick
      nix
      nodePackages.prettier
      openssh_hpnWithKerberos
      python3Full
      (ripgrep.override { withPCRE2 = true; })
      ruff # Python linting LSP
      sqlite
      supercollider
      xclip
      zstd
    ] ++ userPackages;

  emacsLinuxDeps = with pkgs; [ sbcl ];

  myEmacsWithPackages = emacs:
    let
      # transientVersion = "0.9.1";
      # transientSha256 = "sha256-TEryawJiPZU6bWnrO+/TDwJtjE6VP5MwWYUdCluTZAM=";

      baseEmacsPkgs = (pkgs.emacsPackagesFor emacs);
      updatedEmacsPkgs = baseEmacsPkgs.overrideScope (prev: final: {
        doom-two-tone-themes = prev.trivialBuild {
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
            homepage = "https://github.com/eliraz-refael/doom-two-tone-themes";
            description = "Two-toned themes for Doom Emacs.";
            license = pkgs.lib.licenses.gpl3Plus;
          };

          gptel = pkgsUnstable.emacsPackages.gptel;
        };

        ## Can't be found for some fucking reason
        #
        # transient = prev.trivialBuild {
        #   pname = "transient";
        #   inherit version;
        #   src = pkgs.fetchFromGitHub {
        #     owner = "magit";
        #     repo = "transient";
        #     rev = "v${version}";
        #     sha256 = transientSha256;
        #   };

        #   installPhase = ''
        #     mkdir -p $out/share/emacs/site-lisp
        #     cp ./lisp/*.el $out/share/emacs/site-lisp/
        #   '';

        #   meta = {
        #     homepage = "https://github.com/magit/transient";
        #     description = "A transient command interface for Emacs";
        #     license = pkgs.lib.licenses.gpl3Plus;
        #   };
        # };
      });

    in updatedEmacsPkgs.withPackages (epkgs:
      with epkgs; [
        aider
        aidermacs
        babashka
        bash-completion
        chatgpt-shell
        dirvish
        doom-two-tone-themes
        edit-server
        ellama
        elpher
        embark
        flycheck-clj-kondo
        gptel
        # graphviz-dot-mode
        hass
        kubernetes
        inf-clojure
        ivy-prescient
        nix-mode
        noflet
        org-roam
        paredit
        pylint
        restclient
        spotify
        thrift
        transient
      ]);

in {
  config = mkMerge [
    {
      xdg.configFile."doom" = {
        source = niten-doom-config;
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
            ${pkgs.rsync}/bin/rsync -avz --chmod=D2755,F744 ${doom-emacs}/ ${config.xdg.configHome}/emacs/
          '';

        sessionVariables = {
          DOOM_EMACS_SITE_PATH = "${config.xdg.configHome}/doom/site.d";
          DOOM_EMACS_LOCAL_PATH = "${config.xdg.configHome}/emacs-local";
        };
        shellAliases = {
          emacs = "emacs --init-directory=${config.xdg.configHome}/emacs";
          e = "emacsclient --create-frame --tty";
          ew = "emacsclient --create-frame";
        };
      };
    }

    (mkIf pkgs.stdenv.isLinux (let
      emacsPackage = let
        pkg = if systemCfg.desktop.type == "none" then
          pkgs.emacs-unstable-nox
        else
          (if systemCfg.desktop.type == "wayland" then
            pkgs.emacs-unstable-pgtk
          else
            pkgs.emacs-unstable-gtk);
      in myEmacsWithPackages pkg;
    in {
      home.packages = [ emacsPackage ] ++ emacsDeps ++ emacsLinuxDeps;

      systemd.user = {
        services = {
          emacs = {
            Service = {
              Environment = let
                binPath =
                  makeBinPath ([ emacsPackage ] ++ config.home.packages);
              in "PATH=$PATH:${binPath}";
              ExecStartPre = pkgs.writeShellScript "run-doom-sync" ''
                until [ -d ${config.xdg.configHome}/emacs ]; do sleep 1; done

                ${pkgs.bash}/bin/bash ${config.xdg.configHome}/emacs/bin/doom sync

                if [ -d $HOME/.emacs.d ]; then
                  echo "removing old emacs config in ~/.emacs.d"
                fi
              '';
              TimeoutStartSec = "30min";
            };
          };
        };
      };

      services.emacs = {
        enable = true;
        package = emacsPackage;
        client = {
          enable = true;
          arguments = [ "--create-frame" ];
        };
        extraOptions = [ "--init-directory=${config.xdg.configHome}/emacs" ];
        defaultEditor = true;
        startWithUserSession = true;
      };
    }))

    (mkIf pkgs.stdenv.isDarwin
      (let emacsPackage = myEmacsPackagesFor pkgs.emacs29;
      in {
        home.packages = [ emacsPackage ] ++ emacsDeps;
        launchd = {
          enable = true;
          agents.emacs = {
            enable = true;
            config = {
              ProgramArguments = [
                "${pkgs.bash}/bin/bash"
                "-l"
                "-c"
                "${emacsPackage}/bin/emacs --fg-daemon"
              ];
              StandardErrorPath =
                "${config.home.homeDirectory}/Library/Logs/emacs-daemon.stderr.log";
              StandardOutPath =
                "${config.home.homeDirectory}/Library/Logs/emacs-daemon.stdout.log";
              RunAtLoad = true;
              KeepAlive = true;
            };
          };
        };
      }))
  ];
}

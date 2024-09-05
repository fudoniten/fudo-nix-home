systemCfg:

{ doom-emacs, niten-doom-config, ... }:

{ config, lib, pkgs, ... }:

with lib;
let
  doomEmacsEnv = ''
    export PATH="${config.xdg.configHome}/emacs/bin:${config.xdg.configHome}/doom/bin:$PATH"
  '';

  emacsDeps = with pkgs; [
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
    bash
    clojure-lsp
    clojure
    sbcl
    curl
    gnugrep
    nodePackages.prettier
  ];

  myEmacsPackagesFor = emacs:
    (pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs:
      with epkgs; [
        chatgpt-shell
        dirvish
        elpher
        flycheck-clj-kondo
        hass
        kubernetes
        pylint
        spotify
        thrift
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
          pkgs.emacs-nox
        else
          (if systemCfg.desktop.type == "wayland" then
            pkgs.emacs-pgtk
          else
            pkgs.emacs-gtk);
      in myEmacsPackagesFor pkg;
    in {
      home.packages = [ emacsPackage ] ++ emacsDeps;
      
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
      (let emacsPackage = myEmacsPackagesFor pkgs.emacs-macport;
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

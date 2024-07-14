systemCfg:

{ doom-emacs, niten-doom-config, ... }:

{ config, lib, pkgs, ... }:

with lib;
let
  doomEmacsEnv = ''
    export PATH="${config.xdg.configHome}/emacs/bin:$PATH"
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
  ];

  myEmacsPackagesFor = emacs:
    (pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs:
      with epkgs; [
        chatgpt-shell
        elpher
        flycheck-clj-kondo
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

      home.activation.installDoomEmacs =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -d ${config.xdg.configHome}/emacs ]; then
            mkdir -p ${config.xdg.configHome}/emacs
          fi
          ${pkgs.rsync}/bin/rsync -avz --chmod=D2755,F744 ${doom-emacs}/ ${config.xdg.configHome}/emacs/
        '';
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
      home = {
        packages = [ emacsPackage ];
        shellAliases = {
          e = "emacsclient --create-frame --tty";
          ew = "emacsclient --create-frame";
        };
      };

      systemd.user.services = {
        emacs = {
          Service = {
            Environment =
              let binPath = makeBinPath ([ emacsPackage ] ++ emacsDeps);
              in "PATH=$PATH:${binPath}";
            ExecStartPre = pkgs.writeShellScript "run-doom-sync" ''
              until [ -d ${config.xdg.configHome}/emacs ]; do sleep 1; done

              ${pkgs.bash}/bin/bash ${config.xdg.configHome}/emacs/bin/doom sync
            '';
            TimeoutStartSec = "30min";
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
        defaultEditor = true;
        startWithUserSession = true;
      };
    }))

    (mkIf pkgs.stdenv.isDarwin
      (let emacsPackage = myEmacsPackagesFor pkgs.emacs29;
      in {
        home.packages = [ emacsPackage ];
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

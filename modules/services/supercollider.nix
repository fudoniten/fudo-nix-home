# SuperCollider Audio Synthesis Server Module
#
# This module provides a systemd user service for running the SuperCollider
# audio synthesis server (scsynth). SuperCollider is a platform for audio
# synthesis and algorithmic composition, used by musicians, artists, and
# researchers working with sound.
#
# The service starts automatically with the graphical session and restarts
# on failure. It creates the necessary synthdef directory if it doesn't exist.
#
# Usage:
#   services.supercollider = {
#     enable = true;
#     port = 57110;        # Default SC port
#     memory = 8192;       # Memory allocation in MB
#     listen-address = "127.0.0.1";  # Bind address
#   };
#
# Environment variables set:
#   SUPERCOLLIDER_HOST - The listen address
#   SUPERCOLLIDER_PORT - The server port

{ config, lib, pkgs, ... }:

with lib;
let cfg = config.services.supercollider;

in {
  options.services.supercollider = with types; {
    enable = mkEnableOption "Enable SuperCollider audio synthesis server.";

    port = mkOption {
      type = port;
      description = "Port on which to listen of TCP connections.";
    };

    listen-address = mkOption {
      type = str;
      description =
        "IP address on which to listen for connections. 0.0.0.0 for all addresses.";
      default = "127.0.0.1";
    };

    memory = mkOption {
      type = int;
      description = "Number of memory (in megabytes) to allocate to scsynth.";
      default = 1024;
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services = {
      supercollider = {

        Unit = {
          Description = "SuperCollider Audio Synthesis Server.";
          X-RestartIfChanged = true;
        };

        Install.WantedBy = [ "graphical-session.target" ];

        Service = {
          ExecStart = concatStringsSep " " [
            "${pkgs.supercollider-with-sc3-plugins}/bin/scsynth"
            "-u ${toString cfg.port}"
            "-B ${cfg.listen-address}"
            "-m ${toString cfg.memory}"
          ];
          ExecStartPre = let
            pre-script = pkgs.writeShellScript "supercollider-prep.sh" ''
              SYNTHDIR=$HOME/.local/share/SuperCollider/synthdefs
              if [[ ! -d $SYNTHDIR ]]; then
                ${pkgs.coreutils}/bin/mkdir -p $SYNTHDIR
                ${pkgs.coreutils}/bin/chown $USER $SYNTHDIR
              fi
            '';
          in "${pre-script}";
          Restart = "on-failure";
        };
      };
    };

    home.sessionVariables = {
      SUPERCOLLIDER_HOST = cfg.listen-address;
      SUPERCOLLIDER_PORT = cfg.port;
    };
  };
}

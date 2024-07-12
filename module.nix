inputs:

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.fudo.home-manager;

  userOpts = {
    options = with types; {
      username = mkOption { type = str; };
      email = mkOption { type = str; };
      home-directory = mkOption { type = str; };
      config-user = mkOption {
        type = nullOr str;
        description = "Name of user for which to generate config.";
        default = null;
      };
    };
  };
in {
  options.fudo.home-manager = with types; {
    enable = mkEnableOption "Enable Home Manager for known users.";

    users = mkOption {
      type = listOf (submodule userOpts);
      description =
        "List of users for whom to generate a homedir, if available.";
      default = [ ];
    };

    system.desktop.type = mkOption {
      type = enum [ "x" "wayland" "darwin" "none" ];
      default = "none";
    };
  };

  config = mkIf cfg.enable {
    home-manager = let
      homeFileExists = userOpts:
        pathExists "./user/${userOpts.config-user}.nix";
    in {
      users = genAttrs (filter homeFileExists cfg.users) (userOpts:
        import "./users/${userOpts.config-user}.nix" inputs userOpts
        config.fudo.home-manager.system config);
    };
  };
}

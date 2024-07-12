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

    system = {
      desktop.type = mkOption {
        type = enum [ "x" "wayland" "darwin" "none" ];
        default = "none";
      };

      stateVersion = mkOption {
        type = str;
        description =
          "State version of the parent host, which should match the user home.";
      };
    };
  };

  config = mkIf cfg.enable (let
    homeFileExists = userOpts: pathExists "./user/${userOpts.config-user}.nix";

    existingUsers = filter homeFileExists cfg.users;
  in mkMerge [
    {
      home-manager.users =
        genAttrs (map ({ username, ... }: username) existingUsers)
        (username: { home = { inherit (cfg.system) stateVersion; }; });
    }
    {
      home-manager.users = listToAttrs (map
        ({ username, config-user, ... }@opts:
          let target = if isNull config-user then username else config-user;
          in nameValuePair username (import "./users/${target}.nix" inputs opts
            config.fudo.home-manager.system)) existingUsers);
    }
  ]);
}

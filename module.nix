# Fudo Home Manager NixOS Module
#
# This module integrates Home Manager configurations into NixOS systems.
# It provides the `fudo.home-manager` option namespace for configuring
# user home directories declaratively.
#
# Features:
# - Automatic user configuration loading from users/<username>.nix
# - Desktop type configuration (x, wayland, darwin, none)
# - Stylix theming integration
# - Support for custom user-to-config mappings (config-user option)
# - Two deploy modes (deployMode): the generation can ride in the system
#   closure, or ship as its own deploy-rs profile
# - A place for the system layer to contribute per-user Home Manager config
#   that works in both modes (extraUserModules)
#
# Usage:
#   fudo.home-manager = {
#     enable = true;
#     users = [{
#       username = "niten";
#       email = "niten@fudo.org";
#       home-directory = "/home/niten";
#     }];
#     system = {
#       desktop.type = "wayland";
#       stateVersion = "25.05";
#     };
#   };

{ stylix, nixpkgsUnstable, ... }@inputs:

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.fudo.home-manager;

  # Whether *this* layer generates the Home Manager configuration.
  #
  # In "profile" mode the options are still declared and still resolve --
  # the deploy flake reads `users` and `system` off the host's evaluation to
  # decide what to build -- but nothing here writes `home-manager.users`,
  # because the generation ships as its own deploy-rs profile instead.
  #
  # Note this is not the same as `enable = false`. A disabled host has no
  # Home Manager at all and must not get a profile; a profile-mode host has
  # one that arrives by another route. Only the option can tell them apart,
  # which is why it exists rather than the deploy flake keying off `enable`.
  systemManaged = cfg.enable && cfg.deployMode == "system";

  # Users reaching `home-manager.users` from somewhere other than this
  # module. Forced only inside the profile-mode assertion below, so the
  # merge it triggers costs nothing in the default "system" mode.
  strayHomeUsers = attrNames config.home-manager.users;

  userOpts.options = with types; {
    username = mkOption { type = str; };
    email = mkOption { type = str; };
    home-directory = mkOption { type = str; };
    config-user = mkOption {
      type = nullOr str;
      description = "Name of user for which to generate config.";
      default = null;
    };
  };

  getConfigUser = { username, config-user, ... }:
    if isNull config-user then username else config-user;

  versionSetModule = usernames: stateVersion:
    { ... }: {
      config = mkIf systemManaged {
        home-manager.users =
          genAttrs usernames (username: { home = { inherit stateVersion; }; });
      };
    };

  hmModulesModule = usernames:
    { ... }: {
      config = mkIf systemManaged {
        home-manager.users = listToAttrs (map ({ username, ... }@userOpts:
          nameValuePair username {
            imports = [
              (import ./modules/modules.nix {
                inherit inputs userOpts;
                systemOpts = config.fudo.home-manager.system;
              })
            ];
          }) existingUsers);
      };
    };

  commonModule = usernames:
    { ... }: {
      config = mkIf systemManaged {
        home-manager.users = genAttrs usernames
          (username: { imports = [ stylix.homeModules.stylix ]; });
      };
    };

  # Home Manager config contributed by the *system* layer -- config that
  # depends on data this repo has no access to, such as the Kerberos realms
  # behind a user's .k5login.
  #
  # It exists so that layer has somewhere to put such config other than
  # `home-manager.users`, which only the system deploy mode can reach. A
  # module written straight there would keep being applied in profile mode,
  # where the NixOS side is supposed to have stopped managing the user
  # entirely, and the host would activate a second generation aimed at the
  # same lineage as the one the home profile deploys.
  #
  # Keyed by username rather than filtered against `existingUsers`: the
  # system layer contributes for users this repo may have no `users/<n>.nix`
  # for at all (root, and any local user without one), which is what it did
  # when it wrote `home-manager.users` directly.
  extraModulesModule = { ... }: {
    config = mkIf systemManaged {
      home-manager.users =
        mapAttrs (_: modules: { imports = modules; }) cfg.extraUserModules;
    };
  };

  # In profile mode, nothing may reach `home-manager.users` -- see the
  # comment on `extraUserModules`. The failure this catches is silent
  # otherwise: the host looks converted, and goes on activating a system-side
  # generation underneath the profile.
  profileGuardModule = { ... }: {
    config = mkIf (cfg.enable && cfg.deployMode == "profile") {
      assertions = [{
        assertion = strayHomeUsers == [ ];
        message = ''
          fudo.home-manager.deployMode is "profile", but home-manager.users
          is non-empty: ${concatStringsSep ", " strayHomeUsers}

          In profile mode the per-user generation is deployed as its own
          deploy-rs profile, so the NixOS side must not build one too --
          both would be aimed at the same generation lineage.

          Whatever defines those users should contribute through
          fudo.home-manager.extraUserModules instead, which both deploy
          modes consume.
        '';
      }];
    };
  };

  homeFileExists = userOpts: pathExists ./users/${getConfigUser userOpts}.nix;

  existingUsers = filter homeFileExists cfg.users;

in {
  options.fudo.home-manager = with types; {
    enable = mkEnableOption "Enable Home Manager for known users.";

    deployMode = mkOption {
      type = enum [ "system" "profile" ];
      description = ''
        How this host's Home Manager generation reaches it.

        "system" (the default) is the historical behaviour: the generation is
        built into the system closure and activated by switch-to-configuration.

        "profile" means it is deployed separately, as its own deploy-rs
        profile. The options here are still declared and still resolve -- the
        deploy flake reads them off this host's evaluation to decide what to
        build -- but nothing in this module writes `home-manager.users`, and
        it is an error for anything else to either.

        Distinct from `enable = false`, which means the host has no Home
        Manager at all and should get no profile.
      '';
      default = "system";
    };

    users = mkOption {
      type = listOf (submodule userOpts);
      description =
        "List of users for whom to generate a homedir, if available.";
      default = [ ];
    };

    extraUserModules = mkOption {
      type = attrsOf (listOf unspecified);
      description = ''
        Home Manager modules contributed per user by the system layer, for
        configuration that depends on data this repo cannot see.

        Use this rather than defining `home-manager.users` directly: that
        attribute is reachable only in the "system" deploy mode, so a module
        written there is silently kept alive on a host that has moved to
        "profile" mode. Both modes consume this option.

        Keys are usernames, and need not correspond to a `users/<name>.nix`
        in this repo.
      '';
      default = { };
      example = literalExpression ''
        { niten = [ { home.file.".k5login".text = "niten@FUDO.ORG"; } ]; }
      '';
    };

    system = {
      desktop.type = mkOption {
        type = enum [ "x" "wayland" "darwin" "none" ];
        default = "none";
      };

      hostname = mkOption {
        type = str;
        description = ''
          Hostname of the parent system, so a user config can enable
          host-specific features. Empty in the standalone `mkModule` path
          unless the caller passes one, so user configs must tolerate "".
        '';
        default = "";
      };

      stateVersion = mkOption {
        type = str;
        description =
          "State version of the parent host, which should match the user home.";
      };
    };
  };

  imports = let usernames = (map (opts: opts.username) existingUsers);
  in [
    (versionSetModule usernames cfg.system.stateVersion)
    (hmModulesModule usernames)
    (commonModule usernames)
    extraModulesModule
    profileGuardModule
  ];

  config = mkIf systemManaged {
    home-manager = {
      useGlobalPkgs = true;
      users = listToAttrs (map ({ username, ... }@opts:
        nameValuePair username
        (import ./users/${getConfigUser opts}.nix inputs opts
          config.fudo.home-manager.system)) existingUsers);
    };
  };
}

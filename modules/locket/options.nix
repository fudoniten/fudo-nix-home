# Locket Options
#
# This module defines the configuration options for Locket secrets management.
# See LOCKET.md for full documentation on the secrets system.
#
# Key concepts:
# - Profiles: Named groups that control which secrets a host can decrypt
# - Secrets: Encrypted files stored in secrets/<user>/<name>.age
# - Methods: How secrets are placed (symlink to tmpfs or copy to target)
#
# Secrets are only decrypted when the corresponding profile key is present
# in the keyDirectory. Decrypted secrets are stored in tmpfs and cleaned
# up automatically on logout/reboot.

{ lib, ... }:

with lib;

{
  options.locket = {
    enable = mkEnableOption "Locket secrets management";

    keyDirectory = mkOption {
      type = types.str;
      default = ".config/locket/keys";
      description = ''
        Directory containing profile private keys, relative to home directory.
        Keys are named <profile>.key (e.g., default.key, desktop.key).
      '';
    };

    profiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "default" "desktop" ];
      description = ''
        List of profiles this host can decrypt secrets for.
        The host must have the corresponding private key for each profile.
      '';
    };

    identityKeyPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/persistent/secrets/my-key";
      description = ''
        If set, use this single key for all decryption instead of
        profile-based keys. Useful for work laptops where you manually
        provision a key. Path can be absolute or relative to home directory.
      '';
    };

    runtimeDirectory = mkOption {
      type = types.str;
      default = "locket";
      description = ''
        Subdirectory under XDG_RUNTIME_DIR for decrypted secrets.
        Secrets are stored here temporarily and cleaned up on logout.
      '';
    };

    defaultMethod = mkOption {
      type = types.enum [ "symlink" "copy" ];
      default = "symlink";
      description = ''
        Default method for placing secrets at target paths.
        - "symlink": Create symlinks from target to runtime directory (default)
        - "copy": Copy decrypted secrets to target paths directly
        Use "copy" for applications that reject symlinks (e.g., SSH with StrictModes).
      '';
    };

    secrets = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          source = mkOption {
            type = types.path;
            description = "Path to the encrypted .age file";
          };

          target = mkOption {
            type = types.str;
            description = "Target path relative to home directory";
          };

          profiles = mkOption {
            type = types.listOf types.str;
            description = "Profiles that can decrypt this secret";
          };

          mode = mkOption {
            type = types.str;
            default = "0600";
            description = "File permissions for the decrypted secret";
          };

          method = mkOption {
            type = types.nullOr (types.enum [ "symlink" "copy" ]);
            default = null;
            description = ''
              Method for placing this secret. If null, uses defaultMethod.
            '';
          };

          description = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable description of this secret";
          };
        };
      }));
      default = { };
      description = ''
        Secrets to manage. Usually populated automatically from secrets/<user>/ directory.
      '';
    };

    overrides = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to enable this secret on this host";
          };

          target = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Override target path for this secret";
          };

          method = mkOption {
            type = types.nullOr (types.enum [ "symlink" "copy" ]);
            default = null;
            description = "Override method for this secret";
          };

          mode = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Override file permissions for this secret";
          };
        };
      });
      default = { };
      description = ''
        Per-secret overrides for this host. Allows disabling secrets
        or changing their target paths on specific hosts.
      '';
    };
  };
}

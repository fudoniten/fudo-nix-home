# Locket - Profile-based secrets management for Home Manager
#
# This module provides:
# - Systemd user units that watch for profile keys and trigger decryption
# - Automatic cleanup of decrypted secrets on logout/reboot
# - Support for symlink or copy modes for secret placement
#
# Secrets are stored encrypted in the repository and only decrypted when
# the corresponding profile key is present on the host. Decrypted secrets
# are stored in tmpfs (XDG_RUNTIME_DIR) for automatic cleanup.
#
# See LOCKET.md for full documentation and usage instructions.

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.locket;

  # -------------------------------------------------------------------------
  # The scan
  #
  # `locket add` writes secrets/<user>/<name>.age beside <name>.json. This
  # turns those pairs into locket.secrets, which is what the scripts below are
  # generated from. Until it existed, the CLI and the module shared a directory
  # and nothing else: every secret encrypted correctly, and none of them was
  # ever read.
  # -------------------------------------------------------------------------

  profilesDir = cfg.secretsDirectory + "/profiles";
  userDir = cfg.secretsDirectory + "/${cfg.user}";

  entriesIn = dir: if builtins.pathExists dir then builtins.readDir dir else { };

  namesWithSuffix = suffix: dir:
    map (removeSuffix suffix) (filter (hasSuffix suffix) (attrNames (entriesIn dir)));

  availableProfiles = namesWithSuffix ".pub" profilesDir;

  metaNames = namesWithSuffix ".json" userDir;
  ageNames = namesWithSuffix ".age" userDir;

  readMeta = name: builtins.fromJSON (builtins.readFile (userDir + "/${name}.json"));

  # Read once, and only for entries that have both halves -- readMeta on a
  # .json whose .age is missing would be reporting on a secret that does not
  # exist.
  pairedNames = filter (name: elem name ageNames) metaNames;

  metaFor = listToAttrs (map (name: nameValuePair name (readMeta name)) pairedNames);

  # A secret this host has no profile for is left out of the closure entirely,
  # rather than shipped as ciphertext it could never open. That is the whole
  # point of profiles: a work machine should not be carrying personal secrets
  # in any form.
  entitled = name:
    let meta = metaFor.${name};
    in intersectLists (meta.profiles or [ ]) cfg.profiles != [ ];

  # `missingFields` is excluded rather than allowed to throw: an entry with no
  # target would fail here with "attribute 'target' missing", deep inside the
  # script generation, instead of with the assertion below that says which file
  # is wrong and what it is missing.
  usableNames = filter (name: !elem name missingFields) pairedNames;

  scannedSecrets = listToAttrs (map (name:
    let meta = metaFor.${name};
    in nameValuePair name {
      source = userDir + "/${name}.age";
      target = meta.target;
      profiles = meta.profiles;
      mode = meta.mode or "0600";
      method = meta.method or null;
      description = meta.description or "";
    }) (filter entitled usableNames));

  # Hand-declared entries win, so locket.secrets stays a usable override.
  allSecrets = (optionalAttrs cfg.scanSecrets scannedSecrets) // cfg.secrets;

  # -------------------------------------------------------------------------
  # Validation
  #
  # `locket check` enforces the same rules before a commit. These are here for
  # the cases it cannot see: a secret that is well-formed but names a profile
  # that was since deleted, or a host configured with no profiles at all.
  # -------------------------------------------------------------------------

  orphanAge = filter (name: !elem name metaNames) ageNames;
  orphanMeta = filter (name: !elem name ageNames) metaNames;

  missingFields = filter (name:
    let meta = metaFor.${name};
    in !(meta ? target) || !(meta ? profiles)) pairedNames;

  unknownProfileRefs = concatMap (name:
    let meta = metaFor.${name};
    in map (p: "${name} -> ${p}")
    (filter (p: !elem p availableProfiles) (meta.profiles or [ ]))) pairedNames;

  scanProblems = optionals cfg.scanSecrets (
    optional (orphanAge != [ ]) ''
      Locket: ciphertext with no metadata in ${toString userDir}:
        ${concatStringsSep "\n        " orphanAge}
      Each <name>.age needs a <name>.json saying where it goes and which
      profiles can open it. Re-add it with `locket add`, or delete it.
    '' ++ optional (orphanMeta != [ ]) ''
      Locket: metadata with no ciphertext in ${toString userDir}:
        ${concatStringsSep "\n        " orphanMeta}
      Nothing will be deployed for these. Remove the stray .json, or re-add
      the secret with `locket add`.
    '' ++ optional (missingFields != [ ]) ''
      Locket: metadata missing a required field (target, profiles):
        ${concatStringsSep "\n        " missingFields}
    '' ++ optional (unknownProfileRefs != [ ]) ''
      Locket: secrets naming a profile that does not exist in
      ${toString profilesDir}:
        ${concatStringsSep "\n        " unknownProfileRefs}
      Create it with `locket profile-create <name>`, or re-encrypt the secret
      to a profile that exists with `locket rekey`.
    '');

  # A record of what locket put where, so cleanup can remove exactly that and
  # nothing else. It lives outside XDG_RUNTIME_DIR deliberately: a `copy`
  # target survives the reboot that clears the tmpfs, so the list of what to
  # clean up has to survive it too.
  placedHelpers = ''
    STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/locket"
    PLACED="$STATE_DIR/placed"

    record_placed() {
      mkdir -p "$STATE_DIR"
      chmod 700 "$STATE_DIR"
      printf '%s\t%s\n' "$1" "$2" >> "$PLACED"
    }

    # Removes only what a previous run recorded. A symlink is checked to be
    # ours before it goes; a copy cannot be checked at all, which is exactly
    # why it has to be recorded rather than inferred from the config.
    remove_placed() {
      [[ -f "$PLACED" ]] || return 0

      local method target link
      while IFS=$'\t' read -r method target; do
        [[ -n "$target" ]] || continue
        if [[ "$method" == "copy" ]]; then
          if [[ -f "$target" && ! -L "$target" ]]; then
            rm -f "$target"
            echo "Locket: Removed copy $target"
          fi
        elif [[ -L "$target" ]]; then
          link="$(readlink "$target" || true)"
          if [[ "$link" == "$RUNTIME_DIR/"* ]]; then
            rm -f "$target"
            echo "Locket: Removed symlink $target"
          fi
        fi
      done < "$PLACED"

      : > "$PLACED"
    }
  '';

  # Build the decrypt script with all configuration baked in
  decryptScript = pkgs.writeShellScript "locket-decrypt" ''
    set -euo pipefail

    # Configuration
    KEY_DIR="$HOME/${cfg.keyDirectory}"
    RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${cfg.runtimeDirectory}"
    DEFAULT_METHOD="${cfg.defaultMethod}"
    PROFILES=(${concatStringsSep " " (map (p: ''"${p}"'') cfg.profiles)})
    IDENTITY_KEY_PATH="${optionalString (cfg.identityKeyPath != null) cfg.identityKeyPath}"

    # Ensure runtime directory exists
    mkdir -p "$RUNTIME_DIR"
    chmod 700 "$RUNTIME_DIR"

    # Find available identity keys
    find_identity_args() {
      local args=()
      
      if [[ -n "$IDENTITY_KEY_PATH" ]]; then
        # Use single identity key if configured
        local key_path="$IDENTITY_KEY_PATH"
        [[ "$key_path" != /* ]] && key_path="$HOME/$key_path"
        if [[ -f "$key_path" ]]; then
          args+=("-i" "$key_path")
        fi
      else
        # Use profile-based keys
        for profile in "''${PROFILES[@]}"; do
          local key_file="$KEY_DIR/$profile.key"
          if [[ -f "$key_file" ]]; then
            args+=("-i" "$key_file")
          fi
        done
      fi
      
      echo "''${args[@]}"
    }

    # Check if we can decrypt for any of the given profiles.
    #
    # IDENTITY_KEY_PATH changes where the key comes from, not whether the
    # profiles are checked. It used to short-circuit to "try everything", so a
    # work laptop attempted every personal secret and logged a decryption
    # failure for each -- entitlement is what `profiles` means, and a fixed key
    # file is just a different way of holding it.
    can_decrypt_profiles() {
      local secret_profiles=("$@")

      for secret_profile in "''${secret_profiles[@]}"; do
        for host_profile in "''${PROFILES[@]}"; do
          if [[ "$secret_profile" == "$host_profile" ]]; then
            if [[ -n "$IDENTITY_KEY_PATH" ]]; then
              local key_path="$IDENTITY_KEY_PATH"
              [[ "$key_path" != /* ]] && key_path="$HOME/$key_path"
              if [[ -f "$key_path" ]]; then
                return 0
              fi
            elif [[ -f "$KEY_DIR/$host_profile.key" ]]; then
              return 0
            fi
          fi
        done
      done
      return 1
    }

    # Place a decrypted secret at its target location
    place_secret() {
      local runtime_path="$1"
      local target_path="$2"
      local method="$3"
      local mode="$4"
      
      # Expand target path
      local full_target="$HOME/$target_path"
      local target_dir
      target_dir=$(dirname "$full_target")
      
      # Create target directory if needed
      mkdir -p "$target_dir"
      
      # Remove existing file/symlink
      rm -f "$full_target"
      
      if [[ "$method" == "copy" ]]; then
        cp "$runtime_path" "$full_target"
        chmod "$mode" "$full_target"
      else
        # Symlink mode - file in runtime dir already has correct permissions
        ln -s "$runtime_path" "$full_target"
      fi

      record_placed "$method" "$full_target"
    }

    ${placedHelpers}

    echo "Locket: Starting secret decryption..."

    # Anything a previous run placed goes first. A `copy` target is an ordinary
    # file in the home directory: the tmpfs it came from is gone after a
    # reboot, but the copy is not, and locket-cleanup does not run on a host
    # where the user lingers. Without this, a secret removed from the
    # repository stays on disk indefinitely.
    remove_placed

    IDENTITY_ARGS=$(find_identity_args)

    if [[ -z "$IDENTITY_ARGS" ]]; then
      echo "Locket: No identity keys found, skipping decryption"
      exit 0
    fi

    # Process each secret
    ${concatStringsSep "\n" (mapAttrsToList (name: secret:
      let
        override = cfg.overrides.${name} or { enable = true; };
        enabled = override.enable or true;
        target = if override.target != null then override.target else secret.target;
        method = if override.method != null then override.method 
                 else if secret.method != null then secret.method 
                 else cfg.defaultMethod;
        mode = if override.mode != null then override.mode else secret.mode;
        profilesStr = concatStringsSep " " (map (p: ''"${p}"'') secret.profiles);
      in optionalString enabled ''
        # Secret: ${name}
        SECRET_PROFILES=(${profilesStr})
        if can_decrypt_profiles "''${SECRET_PROFILES[@]}"; then
          echo "Locket: Decrypting ${name}..."
          RUNTIME_PATH="$RUNTIME_DIR/${name}"
          if ${pkgs.age}/bin/age -d $IDENTITY_ARGS -o "$RUNTIME_PATH" "${secret.source}"; then
            chmod ${mode} "$RUNTIME_PATH"
            place_secret "$RUNTIME_PATH" "${target}" "${method}" "${mode}"
            echo "Locket: ${name} -> ~/${target}"
          else
            echo "Locket: Failed to decrypt ${name} (see age's error above)"
          fi
        else
          echo "Locket: Skipping ${name} (no matching profile key)"
        fi
      '') allSecrets)}

    echo "Locket: Decryption complete"
  '';

  # Build the cleanup script
  cleanupScript = pkgs.writeShellScript "locket-cleanup" ''
    set -euo pipefail

    RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${cfg.runtimeDirectory}"

    ${placedHelpers}

    echo "Locket: Cleaning up secrets..."

    # Driven by what was actually placed, not by re-deriving targets from the
    # configuration. The configuration is the wrong source: it describes what
    # *this* generation would place, and cleanup runs against whatever the
    # previous one did.
    remove_placed

    # Remove runtime directory
    if [[ -d "$RUNTIME_DIR" ]]; then
      rm -rf "$RUNTIME_DIR"
      echo "Locket: Removed runtime directory"
    fi

    echo "Locket: Cleanup complete"
  '';

in {
  imports = [ ./options.nix ];

  config = mkIf cfg.enable {
    assertions = [{
      assertion = cfg.profiles != [ ];
      message = ''
        Locket is enabled for ${cfg.user} but locket.profiles is empty, so no
        secret is decryptable on this host and nothing will be deployed.

        Profiles are what entitle a host to a secret; a key without one opens
        nothing. Set locket.profiles to the profiles this host should hold
        (see `locket profile-list`), or set locket.enable = false.
      '';
    }] ++ map (problem: {
      assertion = false;
      message = problem;
    }) scanProblems;

    # Ensure age is available
    home.packages = [ pkgs.age ];

    # Install the scripts
    home.file.".local/bin/locket-decrypt" = {
      source = decryptScript;
      executable = true;
    };

    home.file.".local/bin/locket-cleanup" = {
      source = cleanupScript;
      executable = true;
    };

    # Systemd user units for automatic decryption.
    #
    # The path unit covers "keys arrive later" -- it also fires immediately if
    # the glob already matches when it starts, which is the ordinary login on a
    # machine whose keys are in place. The activation entry below covers the
    # remaining case, a switch without a re-login.
    systemd.user.paths.locket-secrets = {
      Unit.Description = "Watch for Locket profile keys";
      Path = {
        PathExistsGlob = "%h/${cfg.keyDirectory}/*.key";
        Unit = "locket-decrypt.service";
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.services.locket-decrypt = {
      Unit = {
        Description = "Decrypt Locket user secrets";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${decryptScript}";
        RemainAfterExit = true;
      };
    };

    # Cleanup service - runs when the user's systemd instance stops.
    #
    # `exit.target` is not reached for a lingering user, so on a host with
    # `loginctl enable-linger` this never fires. That is survivable rather than
    # correct: what it would have removed, locket-decrypt now removes at the
    # start of its next run, from the same record. The window is "until the
    # next decrypt" instead of "until the next reboot".
    systemd.user.services.locket-cleanup = {
      Unit = {
        Description = "Cleanup Locket secrets on logout";
        DefaultDependencies = false;
        Before = [ "shutdown.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${cleanupScript}";
      };
      Install.WantedBy = [ "exit.target" ];
    };

    # Ensure key directory exists
    home.activation.locketKeyDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/${cfg.keyDirectory}"
      $DRY_RUN_CMD chmod 700 "$HOME/${cfg.keyDirectory}"
    '';

    # Re-run the decrypt after a switch, so a secret added or retargeted since
    # the last login lands without one.
    #
    # Only if it is already active: inactive means no keys are present, and
    # starting it then would just log that and exit. After reloadSystemd, or
    # the restart picks up the previous generation's script.
    home.activation.locketDecrypt = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      if ${pkgs.systemd}/bin/systemctl --user --quiet is-active locket-decrypt.service 2>/dev/null; then
        $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user restart locket-decrypt.service || true
      fi
    '';
  };
}

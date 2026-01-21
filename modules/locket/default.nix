{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.locket;

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

    # Check if we can decrypt for any of the given profiles
    can_decrypt_profiles() {
      local secret_profiles=("$@")
      
      if [[ -n "$IDENTITY_KEY_PATH" ]]; then
        local key_path="$IDENTITY_KEY_PATH"
        [[ "$key_path" != /* ]] && key_path="$HOME/$key_path"
        [[ -f "$key_path" ]]
        return
      fi
      
      for secret_profile in "''${secret_profiles[@]}"; do
        for host_profile in "''${PROFILES[@]}"; do
          if [[ "$secret_profile" == "$host_profile" ]]; then
            local key_file="$KEY_DIR/$host_profile.key"
            if [[ -f "$key_file" ]]; then
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
    }

    echo "Locket: Starting secret decryption..."

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
          if ${pkgs.age}/bin/age -d $IDENTITY_ARGS -o "$RUNTIME_PATH" "${secret.source}" 2>/dev/null; then
            chmod ${mode} "$RUNTIME_PATH"
            place_secret "$RUNTIME_PATH" "${target}" "${method}" "${mode}"
            echo "Locket: ${name} -> ~/${target}"
          else
            echo "Locket: Failed to decrypt ${name} (missing key or corrupt file)"
          fi
        else
          echo "Locket: Skipping ${name} (no matching profile key)"
        fi
      '') cfg.secrets)}

    echo "Locket: Decryption complete"
  '';

  # Build the cleanup script
  cleanupScript = pkgs.writeShellScript "locket-cleanup" ''
    set -euo pipefail

    RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${cfg.runtimeDirectory}"

    echo "Locket: Cleaning up secrets..."

    # Remove symlinks pointing to our runtime directory
    ${concatStringsSep "\n" (mapAttrsToList (name: secret:
      let
        override = cfg.overrides.${name} or { enable = true; };
        enabled = override.enable or true;
        target = if override.target != null then override.target else secret.target;
        method = if override.method != null then override.method 
                 else if secret.method != null then secret.method 
                 else cfg.defaultMethod;
      in optionalString enabled ''
        # Cleanup: ${name}
        TARGET="$HOME/${target}"
        if [[ "${method}" == "symlink" ]] && [[ -L "$TARGET" ]]; then
          LINK_TARGET=$(readlink "$TARGET" || true)
          if [[ "$LINK_TARGET" == "$RUNTIME_DIR/"* ]]; then
            rm -f "$TARGET"
            echo "Locket: Removed symlink ${target}"
          fi
        elif [[ "${method}" == "copy" ]] && [[ -f "$TARGET" ]]; then
          rm -f "$TARGET"
          echo "Locket: Removed copy ${target}"
        fi
      '') cfg.secrets)}

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

    # Systemd user units for automatic decryption
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

    # Cleanup service - runs when user session ends
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
  };
}

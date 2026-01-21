# Locket

Profile-based secrets management for NixOS Home Manager.

Locket encrypts secrets to profile-specific keys, allowing fine-grained control over which secrets are available on which hosts. Secrets are decrypted on-demand when profile keys are present, and automatically cleaned up on logout/reboot.

## Concepts

### Profiles

A **profile** is a logical grouping that determines which secrets a host can access. Each profile has its own age keypair.

Example profiles:
- `default` - secrets available on all personal machines
- `desktop` - secrets for GUI/desktop machines  
- `server` - secrets for server machines
- `work` - secrets for work machines (separate from personal)
- `<hostname>` - secrets for a specific host only

A host can have multiple profiles. For example:
- `niten-desktop` might have: `[default, desktop, niten-desktop]`
- `prod-server-1` might have: `[default, server, prod-server-1]`
- `work-laptop` might have: `[work, work-laptop]` (no `default` - personal secrets excluded)

### Encryption Model

Each secret is encrypted to one or more profile public keys. A host can decrypt a secret if it has **any** of the corresponding profile private keys.

### Secret Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│  ENCRYPTION (your workstation):                             │
│    locket add niten ssh-github --profiles default,desktop   │
│    → Encrypts to profile public keys                        │
│    → Creates .age (encrypted) and .json (metadata) files    │
│    → Committed to repository                                │
│                                                             │
│  DEPLOYMENT (deploy-rs):                                    │
│    → Encrypted .age files copied to target                  │
│    → Home Manager activation sets up systemd units          │
│    → Secrets remain encrypted (no keys present yet)         │
│                                                             │
│  LOGIN (SSH to server):                                     │
│    → Copy profile keys to ~/.config/locket/keys/            │
│    → Systemd path unit detects key, triggers decryption     │
│    → Secrets decrypted to tmpfs, linked to target paths     │
│                                                             │
│  LOGOUT/REBOOT:                                             │
│    → tmpfs cleared automatically                            │
│    → Symlinks become dangling (secrets gone)                │
└─────────────────────────────────────────────────────────────┘
```

## Dependencies

The `locket` scripts use `nix-shell` shebangs to automatically provide all required dependencies when run on NixOS or any system with Nix installed. The scripts will automatically fetch and use:

- `age` / `age-keygen` - Encryption/decryption tool
- `jq` - JSON parser for metadata files
- `bash` - Shell interpreter
- `coreutils` - Standard Unix utilities
- `findutils` - File search utilities
- `gnugrep` - Text search
- `gnused` - Stream editor (for some operations)
- `openssh` - SSH/SCP (for `locket-copy-keys` only)

**No manual installation required!** The first time you run a locket script, Nix will automatically provide these dependencies. This ensures the scripts work consistently across all NixOS hosts without relying on global system state.

### Optional: Add to User Profile

While not required (thanks to the nix-shell shebangs), you may want to add these packages to your user profile for general use:

```nix
home.packages = with pkgs; [
  age      # For manual encryption/decryption
  jq       # For inspecting secret metadata
];
```

## Quick Start

### 1. Enable the Pre-commit Hook

```bash
git config core.hooksPath .githooks
```

This ensures secrets are validated before commits.

### 2. Create Your First Profile

```bash
./bin/locket profile-create default
```

This will:
1. Generate an age keypair
2. Save the public key to `secrets/profiles/default.pub`
3. Display the private key **once** - save it securely!

Store the private key:
```bash
mkdir -p ~/.config/locket/keys
echo 'AGE-SECRET-KEY-1...' > ~/.config/locket/keys/default.key
chmod 600 ~/.config/locket/keys/default.key
```

### 3. Add a Secret

```bash
./bin/locket add niten ssh-github \
  --target ".ssh/id_github" \
  --profiles default,desktop \
  --mode 0600 \
  --method copy \
  --description "GitHub SSH key"
```

This opens your `$EDITOR` to enter the secret content, then encrypts it.

Alternatively, read from a file:
```bash
./bin/locket add niten api-token \
  --target ".config/myapp/token" \
  --profiles default \
  --file /path/to/token
```

### 4. Configure a Host

In your NixOS/Home Manager configuration:

```nix
{
  locket = {
    enable = true;
    profiles = [ "default" "desktop" ];
    
    # Optional: customize key directory
    # keyDirectory = ".config/locket/keys";
    
    # Optional: use copy instead of symlink by default
    # defaultMethod = "copy";
    
    # Optional: for work laptops with a single hardcoded key
    # identityKeyPath = "/persistent/secrets/my-key";
  };
}
```

### 5. Deploy

Deploy with `deploy-rs` as usual. Secrets remain encrypted on the target.

### 6. Copy Keys to Host

```bash
# Copy specific profiles
./bin/locket-copy-keys myhost default desktop

# Or manually
scp ~/.config/locket/keys/default.key user@host:.config/locket/keys/
```

Once keys are present, the systemd path unit triggers decryption automatically.

## CLI Reference

### `locket profile-create <name>`

Create a new profile keypair.

```bash
locket profile-create desktop
```

### `locket profile-list`

List all profiles and their usage.

```bash
locket profile-list
```

### `locket add <user> <name> [options]`

Add a new secret.

**Required:**
- `<user>` - Username
- `<name>` - Secret name
- `--target <path>` - Target path relative to `$HOME`
- `--profiles <p1,p2,...>` - Comma-separated list of profiles

**Optional:**
- `--mode <mode>` - File permissions (default: `0600`)
- `--method <symlink|copy>` - Placement method (default: `symlink`)
- `--description <text>` - Human-readable description
- `--file <path>` - Read content from file instead of editor

```bash
locket add niten ssh-github \
  --target ".ssh/id_github" \
  --profiles default,desktop \
  --mode 0600 \
  --method copy
```

### `locket remove <user> <name>`

Remove a secret.

```bash
locket remove niten ssh-github
locket remove niten api-token --force  # Skip confirmation
```

### `locket edit <user> <name>`

Edit an existing secret's content.

```bash
locket edit niten ssh-github
locket edit niten api-token --key /path/to/key  # Use specific key
locket edit niten api-token --file /path/to/new-content  # Replace from file
```

### `locket rekey [user]`

Re-encrypt secrets after profile key changes.

```bash
locket rekey        # All users
locket rekey niten  # Specific user
```

### `locket list [user]`

List secrets.

```bash
locket list        # All users
locket list niten  # Specific user
```

### `locket check`

Validate secrets directory structure (used by pre-commit hook).

```bash
locket check
locket check --verbose
```

### `locket-copy-keys <host> <profile...>`

Copy profile keys to a remote host.

```bash
locket-copy-keys myserver default desktop
locket-copy-keys myserver --all  # Copy all available keys
```

## Directory Structure

```
fudo-home/
├── secrets/
│   ├── profiles/           # Profile public keys
│   │   ├── default.pub
│   │   ├── desktop.pub
│   │   └── server.pub
│   │
│   ├── niten/              # User secrets
│   │   ├── ssh-github.age  # Encrypted secret
│   │   ├── ssh-github.json # Metadata
│   │   └── ...
│   │
│   └── ken/
│       └── ...
│
├── modules/
│   └── locket/
│       ├── default.nix     # Main module
│       └── options.nix     # Option definitions
│
└── bin/
    ├── locket              # Main CLI
    ├── locket-add
    ├── locket-check
    ├── locket-copy-keys
    ├── locket-edit
    ├── locket-list
    ├── locket-profile-create
    ├── locket-profile-list
    ├── locket-rekey
    └── locket-remove
```

## Metadata Format

Each `.age` file has a companion `.json` file:

```json
{
  "profiles": ["default", "desktop"],
  "target": ".ssh/id_github",
  "mode": "0600",
  "method": "copy",
  "description": "GitHub SSH key for personal repos"
}
```

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `profiles` | Yes | — | Profiles that can decrypt this secret |
| `target` | Yes | — | Path relative to `$HOME` |
| `mode` | No | `0600` | File permissions |
| `method` | No | `symlink` | `symlink` or `copy` |
| `description` | No | — | Human-readable description |

## Nix Module Options

```nix
{
  locket = {
    # Enable locket secrets management
    enable = mkEnableOption "Locket secrets management";

    # Directory containing profile private keys
    # Keys are named <profile>.key (e.g., default.key)
    keyDirectory = mkOption {
      type = types.str;
      default = ".config/locket/keys";
    };

    # Profiles this host can decrypt secrets for
    profiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "default" "desktop" ];
    };

    # Override: use single key instead of profile-based
    # Useful for work laptops with manually provisioned keys
    identityKeyPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/persistent/secrets/my-key";
    };

    # Default method for placing secrets
    defaultMethod = mkOption {
      type = types.enum [ "symlink" "copy" ];
      default = "symlink";
    };

    # Per-secret overrides
    overrides = mkOption {
      type = types.attrsOf (types.submodule { ... });
      default = { };
      example = {
        "ssh-github" = {
          enable = false;  # Disable on this host
        };
        "api-token" = {
          target = ".config/alt-path/token";  # Different path
        };
      };
    };
  };
}
```

## Systemd Units

Locket creates three systemd user units:

### `locket-secrets.path`

Watches for profile keys appearing in the key directory. When a `.key` file appears, it triggers the decrypt service.

### `locket-decrypt.service`

Decrypts secrets to `$XDG_RUNTIME_DIR/locket/` (tmpfs) and creates symlinks/copies at target paths.

### `locket-cleanup.service`

Cleans up decrypted secrets on logout. Triggered by `exit.target`.

## Security Notes

1. **Private keys are never committed** - The `.gitignore` blocks `*.key` files and the pre-commit hook validates this.

2. **Secrets are encrypted at rest** - In the repository and on target hosts until keys are provided.

3. **Secrets are cleaned up automatically** - Stored in tmpfs, cleared on logout/reboot.

4. **Profile isolation** - Work hosts can exclude personal profiles entirely.

5. **Audit trail** - Git history shows metadata changes (who added/modified secrets, which profiles).

## Troubleshooting

### First run is slow

The first time you run a locket script, `nix-shell` needs to fetch dependencies. This is a one-time cost - subsequent runs will be fast as dependencies are cached.

### "No identity keys found"

You need profile keys to decrypt/edit secrets. Either:
- Place keys in `~/.config/locket/keys/<profile>.key`
- Use `--key /path/to/key` flag

### "Profile 'foo' does not exist"

Create the profile first:
```bash
locket profile-create foo
```

### Secrets not decrypting on host

1. Check keys are present: `ls ~/.config/locket/keys/`
2. Check systemd status: `systemctl --user status locket-secrets.path`
3. Manually trigger: `systemctl --user start locket-decrypt.service`
4. Check logs: `journalctl --user -u locket-decrypt.service`

### SSH rejects symlinked key

Some applications (SSH with `StrictModes`) reject symlinked keys. Use `method = "copy"`:
```bash
locket add niten ssh-key --method copy ...
```

Or set globally:
```nix
locket.defaultMethod = "copy";
```

## Migration from Other Tools

### From agenix

1. Decrypt existing secrets
2. Create equivalent profiles
3. Re-encrypt with `locket add --file`
4. Update Nix configuration to use `locket` options

### From sops-nix

Similar process - decrypt, create profiles, re-encrypt with locket.

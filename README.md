# Fudo Nix Home Manager Configuration

Internal repository for managing [Home Manager](https://github.com/nix-community/home-manager) configurations across various systems for the Fudo Project.

**Current users:** hermes, jasper, ken, niten, openclaw, reaper, root, xiaoxuan

## What This Repo Does

- Manages user-specific NixOS/Home Manager configurations for Fudo Project users
- Provides custom modules (Doom Emacs, Hyprland, StumpWM, VR, SuperCollider, Locket secrets) that we commonly use
- Supports multiple desktop environments (X11, Wayland, macOS, headless)
- Can be deployed as a NixOS module or standalone Home Manager configuration

## Repository Structure

```
.
├── flake.nix              # Main flake with inputs and outputs
├── module.nix             # NixOS module for system-wide integration
├── modules/               # Custom Home Manager modules
│   ├── default.nix        # Aggregator (services + locket)
│   ├── modules.nix        # Aggregator (services + programs + styling)
│   ├── locket/            # Profile-based secrets management
│   │   ├── default.nix
│   │   └── options.nix
│   ├── programs/
│   │   ├── doom-emacs.nix # Doom Emacs configuration module
│   │   ├── hyprland.nix   # Hyprland (Wayland) compositor setup
│   │   ├── hyprland/      # Hyprland assets (hypridle, wofi configs)
│   │   ├── quickshell.nix # Quickshell bar (QML desktop shell)
│   │   ├── quickshell/    # Quickshell QML sources
│   │   ├── stumpwm.nix    # StumpWM (X11) window manager
│   │   └── vr.nix         # VR desktop support
│   ├── services/
│   │   └── supercollider.nix # SuperCollider audio server
│   └── styling.nix        # Stylix theming glue
├── secrets/               # Encrypted secrets (Locket)
│   └── profiles/          # Profile public keys
├── bin/                   # Locket CLI tools
│   ├── locket
│   ├── locket-add
│   ├── locket-check
│   └── ...
├── .githooks/             # Pre-commit hook (blocks committing private keys)
├── users/                 # User configurations
│   ├── hermes.nix
│   ├── jasper.nix
│   ├── ken.nix
│   ├── niten.nix
│   ├── openclaw.nix
│   ├── reaper.nix
│   ├── root.nix
│   └── xiaoxuan.nix
├── docs/
│   └── quickshell.md      # Quickshell setup + live-editing workflow
├── run-tests.sh           # Local test runner (mirrors CI)
├── LOCKET.md              # Locket documentation
└── README.md              # This file
```

## Quick Start

### Option 1: NixOS System Integration (Recommended)

If you're on NixOS and want to integrate your user configuration into your system flake:

**1. Add to your system's `flake.nix` inputs:**

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fudo-nix-home = {
      url = "github:fudoniten/fudo-nix-home/26.05";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { nixpkgs, home-manager, fudo-nix-home, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        fudo-nix-home.nixosModules.default
        {
          fudo.home-manager = {
            enable = true;

            users = [{
              username = "niten";  # Your username from users/
              email = "niten@fudo.org";
              home-directory = "/home/niten";
            }];

            system = {
              desktop.type = "wayland";  # "x", "wayland", "darwin", or "none"
              stateVersion = "26.05";
            };
          };
        }
      ];
    };
  };
}
```

**2. Rebuild:**

```bash
sudo nixos-rebuild switch --flake .#your-hostname
```

### Option 2: Standalone Home Manager (Non-NixOS or Limited Access)

Use this if you're on a non-NixOS system or don't have root access.

**1. Install Nix (if needed):**

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

**2. Create a `flake.nix` in a new directory:**

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fudo-nix-home = {
      url = "github:fudoniten/fudo-nix-home/26.05";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { nixpkgs, home-manager, fudo-nix-home, ... }:
  let
    system = "x86_64-linux";  # or "aarch64-darwin" for macOS
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    homeConfigurations."niten" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [
        fudo-nix-home.mkModule.niten {  # Use your username from users/
          username = "niten";
          email = "niten@fudo.org";
          home-directory = "/home/niten";
          stateVersion = "26.05";
          desktopType = "wayland";  # "x", "wayland", "darwin", or "none"
        }
      ];
    };
  };
}
```

**3. Activate:**

```bash
# First time
nix run home-manager/release-26.05 -- switch --flake .#niten

# After that
home-manager switch --flake .#niten
```

## Available Modules

### Locket - Secrets Management

Profile-based secrets management that encrypts secrets to specific profiles, allowing fine-grained control over which secrets are available on which hosts. See [LOCKET.md](LOCKET.md) for full documentation.

**Key Features:**
- Secrets encrypted at rest using [age](https://github.com/FiloSottile/age)
- Profile-based access control (e.g., `default`, `desktop`, `server`, `work`)
- Automatic decryption when profile keys are present
- Automatic cleanup on logout/reboot (stored in tmpfs)

**Quick Start:**
```bash
# Enable pre-commit hook
git config core.hooksPath .githooks

# Create a profile
./bin/locket profile-create default

# Add a secret
./bin/locket add niten ssh-github \
  --target ".ssh/id_github" \
  --profiles default \
  --method copy

# Copy keys to a host
./bin/locket copy-keys myserver default
```

**Nix Configuration:**
```nix
locket = {
  enable = true;
  profiles = [ "default" "desktop" ];
  # defaultMethod = "copy";  # Use copy instead of symlink
};
```

### Programs

#### Doom Emacs (`programs.doom-emacs`)

A comprehensive Doom Emacs setup with package management and desktop integration.

**Options:**
- `enable` - Enable Doom Emacs (boolean)
- `desktopType` - Desktop environment type: "x", "wayland", "darwin", or "none"
- `doomSource` - Source for Doom Emacs installation
- `doomConfigSource` - Source for Doom Emacs configuration
- `emacsPackages` - List of additional Emacs packages to install
- `stateDirectory` - Optional custom state directory (useful for read-only home directories)

**Example:**
```nix
programs.doom-emacs = {
  enable = true;
  desktopType = "wayland";
  doomSource = inputs.doom-emacs;
  doomConfigSource = inputs.my-doom-config;
  emacsPackages = with pkgs.emacsPackages; [
    magit
    org-roam
  ];
};
```

#### Hyprland (`programs.hyprland`)

Opinionated [Hyprland](https://hyprland.org/) Wayland compositor setup, including
Waybar styling and a swaylock configuration. Intended for `desktopType = "wayland"`
users. Enable with `programs.hyprland.enable = true;`. Set
`statusBar = "none"` to suppress the Waybar autostart when something else
(e.g. `programs.quickshell`) provides the bar. See
[`docs/hyprland-cheatsheet.pdf`](docs/hyprland-cheatsheet.pdf) for keybindings.

Every binding is prefixed with `$mod`, which defaults to SUPER. Two ways
to cope with a keyboard that has no physical Super key, depending on
whether you can spare a key:

- **A key to spare:** `kbOptions = "caps:super";` remaps Caps Lock to
  Super_L, or `"menu:super"` does the same with an unused Menu key.
- **No key to spare** (e.g. Caps Lock is already your Ctrl): set
  `modKey = "CTRL ALT";` instead. Software-only, no XKB changes -- see
  niten's config on system7. Hyprland matches a bind's modifiers
  exactly, so a two-key `$mod` doesn't collide with plain Ctrl or plain
  Alt bindings elsewhere (Emacs' Meta key among them). Meant as a
  stand-in until Super is available for real; chords that already add
  SHIFT get a third or fourth key in the meantime.

Avoid changing `$mod` to plain `"ALT"` -- it collides constantly with
Emacs' Meta key, and `programs.doom-emacs` is enabled for every user of
this module.

#### Quickshell (`fudo.quickshell`)

[Quickshell](https://quickshell.org) desktop shell — a QML status bar for
Wayland sessions, intended to run alongside `programs.hyprland`. Enabled for
`niten` on system7 only.

Note the namespace: Home Manager 26.05 has its own `programs.quickshell`
module, which owns the package, config directory and systemd unit. This module
lives at **`fudo.quickshell`** and drives it, adding the parts upstream leaves
to you — the bar QML, a theme **generated from your Stylix scheme** (so
changing `stylix.base16Scheme` restyles the bar, unlike the hardcoded Waybar
CSS), and a live-editing mode.

**Options:**
- `enable` — Enable the Fudo Quickshell bar
- `extraQmlPackages` — Extra Qt QML modules to put on `QML2_IMPORT_PATH`
  (e.g. `pkgs.qt6.qt5compat` for graphical effects)
- `barHeight`, `gap`, `radius` — Bar geometry, passed through to `Theme.qml`
- `systemdTarget` — Target that starts the bar (default
  `hyprland-session.target`, so it does not also start in another session)
- `dev.enable` / `dev.path` — Point the config directory at a writable
  directory for live QML editing without rebuilds

**Example:**
```nix
fudo.quickshell = {
  enable = true;
  dev.enable = true;   # live editing; see docs/quickshell.md
};
```

Enabling this sets `programs.hyprland.statusBar` to `"none"` by default so you
don't get Waybar and Quickshell stacked on top of each other. Anything upstream
already covers (package, `activeConfig`) can be set through
`programs.quickshell` directly.

See [docs/quickshell.md](docs/quickshell.md) for the live-editing workflow and
the `fudo-quickshell` helper.

#### StumpWM (`programs.stumpwm`)

[StumpWM](https://stumpwm.github.io/) tiling window manager for X11 users
(`desktopType = "x"`). Enable with `programs.stumpwm.enable = true;`. See
[`docs/stumpwm-cheatsheet.pdf`](docs/stumpwm-cheatsheet.pdf) for keybindings.

#### VR (`programs.vr`)

VR desktop support module for headset-based workflows. Enable with
`programs.vr.enable = true;`.

### Services

#### SuperCollider (`services.supercollider`)

Audio synthesis server for real-time audio synthesis and algorithmic composition.

**Options:**
- `enable` - Enable SuperCollider server (boolean)
- `port` - Server port (default: 57110)
- `memory` - Memory allocation in MB (default: 8192)

**Example:**
```nix
services.supercollider = {
  enable = true;
  port = 30300;
  memory = 4096;
};
```

## Flake Inputs

This flake includes several specialized inputs:

- **nixpkgs**: NixOS 26.05 package set
- **nixpkgsUnstable**: Unstable channel for bleeding-edge packages
- **home-manager**: Home Manager for declarative dotfile management
- **doom-emacs**: Doom Emacs framework source
- **niten-doom-config**: Example Doom Emacs configuration
- **polymuse**: Over-the-shoulder LLM reviewer for code or prose in Emacs
- **typewrite**: Prints to buffer at a typewriterly pace (used by polymuse)
- **canon**: Repository for project data (architecture/style guides, characters/locations/events) with tools to expose to LLMs
- **fudo-pkgs**: Additional Fudo package collection
- **stylix**: System-wide theming for NixOS and Home Manager

## Adding Yourself as a New User

To add your own configuration to this repo:

**1. Create `users/yourname.nix`**

Start with a minimal configuration (you can look at `users/ken.nix` or `users/jasper.nix` for simple examples):

```nix
inputs:
{ username, email, home-directory, ... }:
systemCfg:
{ config, lib, pkgs, ... }:

with lib;
{
  config = {
    # Basic packages everyone needs
    home.packages = with pkgs; [
      git
      ripgrep
      fd
    ];

    # Git configuration
    programs.git = {
      enable = true;
      userName = username;
      userEmail = email;
    };

    # Required Home Manager settings
    home = {
      inherit username;
      homeDirectory = home-directory;
      stateVersion = systemCfg.stateVersion;
    };
  };
}
```

**2. (Optional) Enable Doom Emacs**

If you want Doom Emacs with your own config:

```nix
programs.doom-emacs = {
  enable = true;
  desktopType = systemCfg.desktop.type;
  doomSource = inputs.doom-emacs;
  doomConfigSource = inputs.your-doom-config;  # Add your config as an input
};
```

**3. (Optional) Enable Locket Secrets**

To manage encrypted secrets for your user:

```nix
locket = {
  enable = true;
  profiles = [ "default" ];  # Profiles this host can decrypt
};
```

Then add secrets using the CLI:
```bash
./bin/locket add yourname my-secret --target ".config/app/secret" --profiles default
```

**4. Add your user to `flake.nix`**

Add an `mkModule` export for your username in the flake outputs.

**5. Test it**

```bash
# Check syntax
nix-instantiate --parse users/yourname.nix

# Try building
nix flake check

# Run tests
./run-tests.sh
```

**6. Submit a PR**

Once it builds successfully, submit a pull request.

## Desktop Type Options

The `desktopType` parameter configures environment-specific settings:

| Type | Description |
|------|-------------|
| `x` | X11/X.org display server |
| `wayland` | Wayland compositor |
| `darwin` | macOS/Darwin systems |
| `none` | Headless/server systems (no GUI) |

## Testing

This repository includes automated testing to ensure configurations build correctly and catch issues early.

### Continuous Integration

GitHub Actions automatically runs tests on every push and pull request:

- **Flake validation**: Ensures the flake structure is correct
- **Static analysis**: Checks for Nix code quality issues with [statix](https://github.com/nerdypepper/statix)
- **Dead code detection**: Finds unused code with [deadnix](https://github.com/astro/deadnix)
- **Format checking**: Validates code formatting with [nixpkgs-fmt](https://github.com/nix-community/nixpkgs-fmt)
- **Module validation**: Verifies NixOS modules and mkModule function exports are correct
- **Configuration tests**: Validates all user configuration files can be loaded
- **Locket validation**: Checks secrets structure, prevents private key commits

### Local Testing

Before pushing changes, run the test suite locally:

```bash
./run-tests.sh
```

This script runs the same checks as CI and will catch most issues before they reach the repository.

### Manual Testing

You can also run individual checks:

```bash
# Validate flake structure
nix flake check

# Check code quality with statix
nix run nixpkgs#statix -- check .

# Find dead/unused code
nix run nixpkgs#deadnix -- --fail .

# Check code formatting
nix run nixpkgs#nixpkgs-fmt -- --check .

# Auto-fix formatting issues
nix run nixpkgs#nixpkgs-fmt .

# Validate module exports
nix eval .#nixosModules.default
nix eval .#mkModule.niten --apply 'x: builtins.isFunction x'

# Check syntax of user configurations
nix-instantiate --parse users/niten.nix

# Check syntax of custom modules
nix-instantiate --parse modules/programs/doom-emacs.nix

# Validate Locket secrets structure
./bin/locket check
```

## Making Changes

When modifying configurations or modules:

1. Run `./run-tests.sh` before committing to catch issues early
2. For secrets changes, enable the pre-commit hook: `git config core.hooksPath .githooks`
3. Update this README if you add new modules or change how things work
4. Keep your user configuration reasonably simple - complex customizations might be better in your own Doom config or similar
5. If you add a new module, add documentation in the relevant section above

## Useful References

- [Home Manager Manual](https://nix-community.github.io/home-manager/) - Official Home Manager documentation
- [NixOS Wiki](https://nixos.wiki/) - Community wiki with lots of examples
- [Nix Flakes](https://nixos.wiki/wiki/Flakes) - Flakes documentation
- [age encryption](https://github.com/FiloSottile/age) - Modern encryption tool used by Locket

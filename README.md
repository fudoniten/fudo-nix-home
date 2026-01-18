# Fudo Nix Home Manager Configuration

Internal repository for managing our team's [Home Manager](https://github.com/nix-community/home-manager) configurations across various systems.

**Current users:** jasper, ken, niten, reaper, root, xiaoxuan

## What This Repo Does

- Manages user-specific NixOS/Home Manager configurations for our team members
- Provides custom modules (Doom Emacs, SuperCollider) that we commonly use
- Supports multiple desktop environments (X11, Wayland, macOS, headless)
- Can be deployed as a NixOS module or standalone Home Manager configuration

## Repository Structure

```
.
├── flake.nix              # Main flake with inputs and outputs
├── module.nix             # NixOS module for system-wide integration
├── modules/               # Custom Home Manager modules
│   ├── programs/
│   │   └── doom-emacs.nix # Doom Emacs configuration module
│   └── services/
│       └── supercollider.nix # SuperCollider audio server
└── users/                 # Team member configurations
    ├── jasper.nix
    ├── ken.nix
    ├── niten.nix
    ├── reaper.nix
    ├── root.nix
    └── xiaoxuan.nix
```

## Quick Start for Team Members

### Option 1: NixOS System Integration (Recommended)

If you're on NixOS and want to integrate your user configuration into your system flake:

**1. Add to your system's `flake.nix` inputs:**

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fudo-nix-home = {
      url = "github:fudoniten/fudo-nix-home";
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
              stateVersion = "24.05";
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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fudo-nix-home = {
      url = "github:fudoniten/fudo-nix-home";
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
          stateVersion = "24.05";
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
nix run home-manager/release-24.05 -- switch --flake .#niten

# After that
home-manager switch --flake .#niten
```

## Available Modules

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

- **nixpkgs**: NixOS 24.05 package set
- **home-manager**: Home Manager for declarative dotfile management
- **doom-emacs**: Doom Emacs framework source
- **niten-doom-config**: Example Doom Emacs configuration
- **polymuse**: Generative music composition engine for Emacs
- **typewrite-el**: Emacs typing/writing utilities (dependency of polymuse)
- **canon-el**: Music notation and composition tools for Emacs
- **fudo-pkgs**: Additional package collection

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

**3. Add your user to `flake.nix`**

Add an `mkModule` export for your username in the flake outputs.

**4. Test it**

```bash
# Check syntax
nix-instantiate --parse users/yourname.nix

# Try building
nix flake check

# Run tests
./run-tests.sh
```

**5. Submit a PR**

Once it builds successfully, submit a pull request.

## Desktop Type Options

The `desktopType` parameter configures environment-specific settings:

- **`x`**: X11/X.org display server
- **`wayland`**: Wayland compositor
- **`darwin`**: macOS/Darwin systems
- **`none`**: Headless/server systems (no GUI)

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
```

## Making Changes

When modifying configurations or modules:
- Run `./run-tests.sh` before committing to catch issues early
- Update this README if you add new modules or change how things work
- Keep your user configuration reasonably simple - complex customizations might be better in your own Doom config or similar
- If you add a new module, add documentation in the relevant section above

## Useful References

- [Home Manager Manual](https://nix-community.github.io/home-manager/) - Official Home Manager documentation
- [NixOS Wiki](https://nixos.wiki/) - Community wiki with lots of examples
- [Nix Flakes](https://nixos.wiki/wiki/Flakes) - Flakes documentation

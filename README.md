# Fudo Nix Home Manager Configuration

A modular [Home Manager](https://github.com/nix-community/home-manager) configuration for managing user environments across NixOS and non-NixOS systems. This flake provides a collection of custom modules, services, and user configurations that can be easily integrated into your system.

## Features

- **Custom Modules**: Doom Emacs integration, SuperCollider audio synthesis server
- **Multiple Desktop Environments**: Support for X11, Wayland, macOS, and headless systems
- **User Profiles**: Pre-configured user environments with sensible defaults
- **Flexible Deployment**: Use as a NixOS module or standalone Home Manager configuration

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
└── users/                 # User-specific configurations
    ├── niten.nix          # Example user configuration
    └── ...
```

## Usage

### As a NixOS Module (Recommended for NixOS Systems)

Add this flake to your NixOS system configuration:

#### 1. Add to your `flake.nix` inputs:

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
              username = "alice";
              email = "alice@example.com";
              home-directory = "/home/alice";
            }];

            system = {
              desktop.type = "wayland";  # Options: "x", "wayland", "darwin", "none"
              stateVersion = "24.05";
            };
          };
        }
      ];
    };
  };
}
```

#### 2. Rebuild your system:

```bash
sudo nixos-rebuild switch --flake .#your-hostname
```

### As a Standalone Home Manager Configuration (Non-NixOS Systems)

For systems where you don't have root access or aren't using NixOS, you can use this as a standalone Home Manager configuration.

#### 1. Install Nix and Home Manager

```bash
# Install Nix (if not already installed)
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

#### 2. Create your Home Manager `flake.nix`:

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
    system = "x86_64-linux";  # or "aarch64-darwin" for Apple Silicon
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    homeConfigurations."alice" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [
        fudo-nix-home.mkModule.niten {
          username = "alice";
          email = "alice@example.com";
          home-directory = "/home/alice";
          stateVersion = "24.05";
          desktopType = "wayland";  # Options: "x", "wayland", "darwin", "none"
        }
      ];
    };
  };
}
```

#### 3. Activate the configuration:

```bash
# First time setup
nix run home-manager/release-24.05 -- switch --flake .#alice

# Subsequent updates
home-manager switch --flake .#alice
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

## Creating Your Own User Configuration

To create a new user configuration, create a file in `users/yourname.nix`:

```nix
inputs:
{ username, email, home-directory, ... }:
systemCfg:
{ config, lib, pkgs, ... }:

with lib;
{
  config = {
    # Enable Doom Emacs
    programs.doom-emacs = {
      enable = true;
      desktopType = systemCfg.desktop.type;
      doomSource = inputs.doom-emacs;
      doomConfigSource = inputs.your-doom-config;
    };

    # Install packages
    home.packages = with pkgs; [
      git
      ripgrep
      fd
    ];

    # Configure git
    programs.git = {
      enable = true;
      userName = username;
      userEmail = email;
    };

    home = {
      inherit username;
      homeDirectory = home-directory;
      stateVersion = systemCfg.stateVersion;
    };
  };
}
```

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
- **Static analysis**: Checks for Nix code quality issues with statix
- **Build tests**: Validates all user configurations can be built
- **Module validation**: Verifies NixOS module exports are correct

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

# Check code quality
nix run nixpkgs#statix -- check .

# Test a specific user configuration
nix eval .#homeConfigurations.niten.config.home.username

# Test building (dry-run, doesn't install)
nix build .#homeConfigurations.niten.activationPackage --dry-run
```

## Contributing

Contributions are welcome! Please ensure your changes:
- Follow the existing code style
- Include appropriate comments
- Update documentation as needed
- Pass all automated tests (run `./run-tests.sh`)
- Test on both NixOS and non-NixOS systems when applicable

## License

This configuration is provided as-is for personal and educational use.

## See Also

- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [NixOS Wiki](https://nixos.wiki/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)

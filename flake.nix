{
  description = "Fudo Home Manager Configuration";

  inputs = {
    # Base package set - NixOS 24.05 stable
    nixpkgs.url = "nixpkgs/nixos-24.05";

    # Home Manager - declarative dotfile and user environment management
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs"; # Use the same nixpkgs version
    };

    # Doom Emacs - an Emacs framework with sensible defaults and a focus on performance
    doom-emacs = {
      url = "github:doomemacs/doomemacs";
      flake = false; # Source-only input
    };

    # Personal Doom Emacs configuration
    niten-doom-config = {
      url = "github:fudoniten/doom-emacs-config";
      flake = false; # Source-only input
    };

    # Polymuse - generative music composition engine for Emacs
    # Provides algorithmic music generation and MIDI integration
    polymuse = {
      url = "github:fudoniten/polymuse";
      flake = false; # Source-only input (Emacs package)
    };

    # Typewrite.el - typing and writing utilities for Emacs
    # Note: This is a dependency of polymuse and doesn't need to be imported separately
    typewrite-el = {
      url = "github:fudoniten/typewrite.el";
      flake = false; # Source-only input (Emacs package)
    };

    # Canon.el - music notation and composition tools for Emacs
    # Works alongside polymuse for music creation workflows
    canon-el = {
      url = "github:fudoniten/canon.el";
      flake = false; # Source-only input (Emacs package)
    };

    # Additional package collection from the Fudo ecosystem
    fudo-pkgs = {
      url = "github:fudoniten/fudo-nix-pkgs/24.05";
      inputs.nixpkgs.follows = "nixpkgs"; # Use the same nixpkgs version
    };
  };

  outputs = { home-manager, ... }@inputs: {
    # NixOS module for system-wide integration
    # Use this when running NixOS and want to manage users system-wide
    nixosModules = rec {
      default = home-configuration;
      home-configuration = {
        imports = [
          home-manager.nixosModules.home-manager
          (import ./module.nix inputs)
        ];
      };
    };

    # Standalone module builder for per-user Home Manager configurations
    # Use this for non-NixOS systems or when running Home Manager standalone
    # Example: home-manager switch --flake .#username
    mkModule.niten = { username, email, home-directory, stateVersion
      , desktopType ? "none", ... }: {
        imports = [
          ./modules # Custom modules (doom-emacs, supercollider, etc.)
          (import ./users/niten.nix inputs {
            inherit username email home-directory;
          } {
            inherit stateVersion;
            desktop.type = desktopType; # "x", "wayland", "darwin", or "none"
          })
        ];
      };
  };
}

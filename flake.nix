# Fudo Home Manager Configuration
#
# This flake provides Home Manager configurations for Fudo Project users.
#
# Outputs:
#   nixosModules.default / nixosModules.home-configuration
#     - NixOS module for system-wide integration via fudo.home-manager options
#
#   mkModule.niten
#     - Standalone Home Manager module for the niten user configuration
#     - Can be used outside of NixOS (e.g., on macOS or non-NixOS Linux)
#
# See README.md for usage examples and documentation.

{
  description = "Fudo Home Manager Configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    nixpkgsUnstable.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    doom-emacs = {
      url = "github:doomemacs/doomemacs";
      flake = false;
    };
    niten-doom-config = {
      url = "github:fudoniten/doom-emacs-config";
      flake = false;
    };
    fudo-pkgs = {
      url = "github:fudoniten/fudo-nix-pkgs/26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    polymuse = {
      url = "github:fudoniten/polymuse/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    typewrite = {
      url = "github:fudoniten/typewrite.el";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    canon = {
      url = "github:fudoniten/canon.el";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { home-manager, ... }@inputs: {
    nixosModules = rec {
      default = home-configuration;
      home-configuration = {
        imports = [
          home-manager.nixosModules.home-manager
          (import ./module.nix inputs)
        ];
      };
    };

    mkModule.niten = { username, email, home-directory, stateVersion
      , desktopType ? "none", ... }: {
        imports = [
          ./modules
          (import ./users/niten.nix inputs {
            inherit username email home-directory;
          } {
            inherit stateVersion;
            desktop.type = desktopType;
          })
        ];
      };
  };
}

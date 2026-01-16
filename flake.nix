{
  description = "Fudo Home Manager Configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    nixpkgsUnstable.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
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
      url = "github:fudoniten/fudo-nix-pkgs/25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    polymuse = {
      url = "github:fudoniten/polymuse/master";
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

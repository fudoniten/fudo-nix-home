{
  description = "Fudo Home Manager Configuration";

  inputs = let version = "24.05";
  in {
    nixpkgs.url = "nixpkgs/nixos-${version}";
    home-manager = {
      url = "github:nix-community/home-manager/release-${version}";
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
      url = "github:fudoniten/fudo-nix-pkgs/${version}";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { home-manager, ... }@inputs: {
    nixosModules = {
      home-configuration = {
        imports = [
          home-manager.nixosModules.home-manager
          (import ./module.nix inputs)
        ];
      };
    };
  };
}

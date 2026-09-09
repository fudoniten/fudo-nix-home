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
    # Doom's module library was moved out of the core repo (upstream commit
    # eb04484, 2026-06-08) and is now the `sources/doom+` git submodule. The
    # `github:` fetcher downloads a tarball, which never contains submodules,
    # so it must be fetched with git+https and `submodules=1` — otherwise
    # `sources/doom+/modules` is empty and no module (ui/popup, lang/*, ...)
    # resolves, which breaks `doom sync` in confusing ways (e.g. the autodefs
    # `set-popup-rules!` and friends silently never get generated).
    doom-emacs = {
      url = "git+https://github.com/doomemacs/doomemacs?submodules=1";
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
    # Provides a Home Manager module (homeModules.beta/twilight/twilight-official)
    # with declarative support for Zen's reworked container/workspace storage
    # (zen-sessions.jsonlz4), not just the legacy policies.json Containers key.
    #
    # Follows nixpkgsUnstable rather than our stable nixpkgs: the package
    # build wants ffmpeg_9, which doesn't exist yet on the nixos-26.05
    # branch (only up to ffmpeg_7 there).
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgsUnstable";
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
      , desktopType ? "none", hostname ? "", ... }: {
        imports = [
          ./modules
          (import ./users/niten.nix inputs {
            inherit username email home-directory;
          } {
            inherit stateVersion hostname;
            desktop.type = desktopType;
          })
        ];
      };
  };
}

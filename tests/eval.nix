# Evaluates user configs through both consumption paths (the NixOS module
# and standalone mkModule) for the platforms they're used on. Evaluation
# only, no builds, so it runs on a Linux CI runner -- aarch64-darwin included.
#
#   nix eval --impure --json --expr \
#     'import ./tests/eval.nix { flake = builtins.getFlake (toString ./.); }'
#
# Each leaf is a home-manager-generation .drv path; any eval error fails.
{ flake }:

let
  inherit (flake.inputs) nixpkgs home-manager;
  inherit (nixpkgs) lib;

  stateVersion = "26.05";

  users = [
    "hermes"
    "jasper"
    "ken"
    "niten"
    "openclaw"
    "reaper"
    "root"
    "xiaoxuan"
  ];

  homeOf = user: if user == "root" then "/root" else "/home/${user}";

  standalone =
    {
      system,
      desktopType,
      hostname ? "",
      home-directory,
    }:
    (home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      modules = [
        (flake.mkModule.niten {
          username = "test";
          email = "test@example.com";
          inherit
            home-directory
            stateVersion
            desktopType
            hostname
            ;
        })
      ];
    }).activationPackage.drvPath;

  nixos =
    {
      desktopType,
      hostname ? "",
    }:
    let
      system = lib.nixosSystem {
        modules = [
          flake.nixosModules.default
          {
            nixpkgs = {
              hostPlatform = "x86_64-linux";
              config.allowUnfree = true;
            };
            system.stateVersion = stateVersion;
            boot.loader.grub.device = "nodev";
            fileSystems."/" = {
              device = "/dev/sda1";
              fsType = "ext4";
            };
            users.users = lib.genAttrs (lib.remove "root" users) (_: {
              isNormalUser = true;
            });
            fudo.home-manager = {
              enable = true;
              users = map (user: {
                username = user;
                email = "${user}@example.com";
                home-directory = homeOf user;
              }) users;
              system = {
                desktop.type = desktopType;
                inherit stateVersion hostname;
              };
            };
          }
        ];
      };
    in
    lib.genAttrs users (user: system.config.home-manager.users.${user}.home.activationPackage.drvPath);

in
{
  standalone = {
    linux-headless = standalone {
      system = "x86_64-linux";
      desktopType = "none";
      home-directory = "/home/test";
    };
    linux-wayland = standalone {
      system = "x86_64-linux";
      desktopType = "wayland";
      hostname = "system7";
      home-directory = "/home/test";
    };
    darwin = standalone {
      system = "aarch64-darwin";
      desktopType = "darwin";
      home-directory = "/Users/test";
    };
  };

  nixos = {
    headless = nixos { desktopType = "none"; };
    wayland = nixos {
      desktopType = "wayland";
      hostname = "system7";
    };
  };
}
